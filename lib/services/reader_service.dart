import 'dart:io';

import 'wbf_capture.dart';

/// What state the fingerprint reader is in.
enum ReaderState {
  /// Reader plugged in, driver OK, scanner software present.
  ready,

  /// No fingerprint reader found on any USB port.
  notConnected,

  /// A reader is plugged in but Windows reports a driver problem.
  driverError,

  /// Kept for completeness: no usable capture method for the reader.
  runtimeMissing,

  /// The scanner helper (`WbfReaderApp.exe` / `FingerprintReaderApp.exe`) is not next to the app.
  appMissing,
}

class ReaderStatus {
  final ReaderState state;
  final String? deviceName;

  /// How this reader is captured: `FingerprintReaderApp.exe` (DigitalPersona
  /// SDK helper) or `wbf` (Windows Biometric Framework, in-process, works with
  /// any reader that has a Windows fingerprint driver).
  final String? helperExe;

  /// The DigitalPersona helper can be used as a fallback when the Windows
  /// Biometric Framework does not see the reader.
  final bool hasDpHelper;

  const ReaderStatus(
    this.state, [
    this.deviceName,
    this.helperExe,
    this.hasDpHelper = false,
  ]);

  bool get isReady => state == ReaderState.ready;

  /// Short text for the dashboard tile.
  String get title {
    switch (state) {
      case ReaderState.ready:
        return 'Reader ready';
      case ReaderState.notConnected:
        return 'Not connected';
      case ReaderState.driverError:
        return 'Driver problem';
      case ReaderState.runtimeMissing:
        return 'Runtime missing';
      case ReaderState.appMissing:
        return 'Reader app missing';
    }
  }

  /// One line of detail for the dashboard tile.
  String get hint {
    switch (state) {
      case ReaderState.ready:
        return (deviceName ?? 'Fingerprint reader') +
            (helperExe == 'wbf' ? ' (Windows)' : '');
      case ReaderState.notConnected:
        return 'Plug in the reader';
      case ReaderState.driverError:
        return 'Reinstall the driver';
      case ReaderState.runtimeMissing:
        return 'No capture method';
      case ReaderState.appMissing:
        return 'Reader helper missing';
    }
  }

  /// Full warning shown when a scan is refused.
  String get warning {
    switch (state) {
      case ReaderState.ready:
        return '';
      case ReaderState.notConnected:
        return 'No fingerprint reader was found. Connect the DigitalPersona '
            'U.are.U reader to a USB port, wait a few seconds, then try again.';
      case ReaderState.driverError:
        return 'The fingerprint reader is connected but Windows reports a '
            'driver problem. Reinstall the reader driver or reconnect the '
            'device, then try again.';
      case ReaderState.runtimeMissing:
        return 'No way to capture from this reader was found. Reinstall '
            'CG Biometric or install the reader manufacturer software.';
      case ReaderState.appMissing:
        return 'The fingerprint helper was not found next to the app. '
            'Reinstall CG Biometric.';
    }
  }
}

class ReaderService {
  /// Checks (without opening the scanner) that a reader is attached and usable.
  static Future<ReaderStatus> check() async {
    if (!Platform.isWindows) return const ReaderStatus(ReaderState.ready);

    // 1. Is a DigitalPersona / Biometric-class device present?
    String raw = '';
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB\VID_05BA*' -or $_.Class -eq 'Biometric' } | ForEach-Object { $_.Status + '|' + $_.FriendlyName }",
      ]).timeout(const Duration(seconds: 15));
      raw = (result.stdout as String).trim();
    } catch (_) {
      // PowerShell unavailable: fall through to the file checks only.
      raw = '';
    }

    String? name;
    if (raw.isEmpty) {
      return const ReaderStatus(ReaderState.notConnected);
    }
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .where((l) => l.contains('|'))
        .toList();
    final ok = lines.where((l) => l.startsWith('OK|')).toList();
    if (ok.isEmpty) {
      return ReaderStatus(
        ReaderState.driverError,
        lines.isEmpty ? null : lines.first.split('|').last,
      );
    }
    name = ok.first.split('|').last;

    // 2. Pick a capture method. DigitalPersona's own SDK when its runtime is
    //    installed, otherwise the Windows Biometric Framework (any reader that
    //    works in "Windows fingerprint setup").
    final dir = File(Platform.resolvedExecutable).parent.path;
    bool has(String file) =>
        File('$dir\\$file').existsSync() ||
        File('$dir\\resources\\$file').existsSync();
    final win = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final dpRuntime =
        File('$win\\System32\\dpfpdd.dll').existsSync() ||
        File('$win\\SysWOW64\\dpfpdd.dll').existsSync() ||
        File('$dir\\dpfpdd.dll').existsSync();
    final wbfAvailable = File('$win\\System32\\winbio.dll').existsSync();

    final dpHelper = dpRuntime && has('FingerprintReaderApp.exe');

    // Windows Biometric Framework first: it gives a clean image and has no
    // extra window. The DigitalPersona helper is only a fallback.
    if (wbfAvailable) {
      return ReaderStatus(ReaderState.ready, name, 'wbf', dpHelper);
    }
    if (dpHelper) {
      return ReaderStatus(
        ReaderState.ready,
        name,
        'FingerprintReaderApp.exe',
        true,
      );
    }
    if (!has('FingerprintReaderApp.exe')) {
      return ReaderStatus(ReaderState.appMissing, name);
    }
    return ReaderStatus(ReaderState.runtimeMissing, name);
  }

  /// A plain-text report about the reader, the driver and Windows' fingerprint
  /// service, for troubleshooting a PC where scanning does not work.
  static Future<String> diagnose() async {
    final out = StringBuffer();
    out.writeln('CG Biometric reader diagnostics');
    out.writeln('Time: ${DateTime.now()}');

    const script = r"""
$ErrorActionPreference = 'SilentlyContinue'
'Administrator: ' + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
'Windows: ' + [Environment]::OSVersion.VersionString
$svc = Get-Service WbioSrvc
'Windows Biometric Service: ' + $svc.Status + ' (start type ' + $svc.StartType + ')'
$pol = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Biometrics').Enabled
'Policy "Allow the use of biometrics": ' + $(if ($null -eq $pol) { 'not set (allowed)' } elseif ($pol -eq 0) { 'DISABLED by policy' } else { 'enabled' })
'--- Devices (VID_05BA or Biometric class)'
$devs = Get-PnpDevice | Where-Object { $_.InstanceId -like 'USB\VID_05BA*' -or $_.Class -eq 'Biometric' }
if (-not $devs) { 'none found' }
foreach ($d in $devs) {
  $id = $d.InstanceId
  $d.Status + ' | class ' + $d.Class + ' | ' + $d.FriendlyName + ' | present ' + $d.Present
  '    id: ' + $id
  '    driver: ' + (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverProvider').Data + ' ' + (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverVersion').Data + ' (' + (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverInfPath').Data + ')'
  '    problem code: ' + (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_ProblemCode').Data
}
'--- Installed fingerprint software'
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -match 'DigitalPersona|U\.are\.U|Crossmatch|HID Global|Fingerprint' } | ForEach-Object { $_.DisplayName + ' ' + $_.DisplayVersion }
""";
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]).timeout(const Duration(seconds: 25));
      out.writeln((r.stdout as String).trim());
      final err = (r.stderr as String).trim();
      if (err.isNotEmpty) out.writeln('(powershell: $err)');
    } catch (e) {
      out.writeln('PowerShell query failed: $e');
    }

    out.writeln('--- Windows Biometric Framework');
    try {
      out.writeln((await probeWindowsBiometric()).join('\n'));
    } catch (e) {
      out.writeln('probe failed: $e');
    }

    final win = Platform.environment['WINDIR'] ?? r'C:\Windows';
    out.writeln('--- Files');
    out.writeln(
      'dpfpdd.dll (DigitalPersona runtime): ${File('$win\\System32\\dpfpdd.dll').existsSync() || File('$win\\SysWOW64\\dpfpdd.dll').existsSync() ? 'present' : 'missing'}',
    );
    final dir = File(Platform.resolvedExecutable).parent.path;
    out.writeln(
      'FingerprintReaderApp.exe: ${File('$dir\\FingerprintReaderApp.exe').existsSync() ? 'present' : 'missing'}',
    );
    final status = await check();
    out.writeln('--- App decision');
    out.writeln(
      'State: ${status.state.name}; method: ${status.helperExe ?? 'none'}; DigitalPersona fallback: ${status.hasDpHelper}',
    );
    return out.toString();
  }
}
