import 'dart:io';

/// Administrator rights, needed for the raw fingerprint image on Windows.
class Elevation {
  /// True when this process already runs as administrator.
  static Future<bool> isElevated() async {
    if (!Platform.isWindows) return true;
    try {
      final r = await Process.run('net', ['session']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Starts a new copy of the app as administrator (Windows shows the usual
  /// permission prompt) and returns true when the user accepted it. The caller
  /// should close this copy afterwards.
  static Future<bool> relaunchAsAdmin() async {
    try {
      final exe = Platform.resolvedExecutable.replaceAll("'", "''");
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "Start-Process -FilePath '$exe' -Verb RunAs -ErrorAction Stop",
      ]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
