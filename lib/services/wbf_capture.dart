import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;

/// Result of a fingerprint capture through the Windows Biometric Framework.
class WbfCaptureResult {
  /// PNG image of the fingerprint, or null on failure.
  final Uint8List? png;

  /// Human readable reason when [png] is null.
  final String? error;

  /// True when Windows refused because the app lacks administrator rights.
  final bool needsAdmin;

  const WbfCaptureResult.ok(this.png) : error = null, needsAdmin = false;
  const WbfCaptureResult.fail(this.error, {this.needsAdmin = false})
    : png = null;

  bool get isOk => png != null;
}

/// Captures a fingerprint from any reader that works in Windows' own
/// "fingerprint setup" (WBF driver), by calling `winbio.dll` directly.
///
/// No helper program is started, so Windows Application Control /
/// Smart App Control has nothing extra to block. The blocking capture call
/// runs in a background isolate so the UI keeps animating.
Future<WbfCaptureResult> captureWithWindowsBiometric() {
  return Isolate.run(_captureBlocking);
}

const _winbioTypeFingerprint = 0x00000008;
const _winbioPoolSystem = 1;
const _winbioFlagDefault = 0x00000000;
const _winbioFlagRaw = 0x00000001;
const _winbioPurposeIdentify = 0x02;
const _winbioDataFlagRaw = 0x20;
const _winbioDataFlagProcessed = 0x80;

bool _isDenied(int hr) {
  final code = hr & 0xFFFFFFFF;
  return code == 0x80070005 || code == 0x80090030;
}

String _describe(int hr) {
  switch (hr & 0xFFFFFFFF) {
    case 0x80098005:
      return 'No reader is available. Is the fingerprint reader connected and enabled in Windows?';
    case 0x80098006:
      return 'The reader is busy. Close other programs that use the fingerprint reader and try again.';
    case 0x80098008:
      return 'The reader is not responding.';
    case 0x80098009:
      return 'The scan was cancelled.';
    case 0x80098010:
      return 'No finger was detected in time. Place your finger on the reader and try again.';
    case 0x80070005:
    case 0x80090030:
      return 'Access denied by Windows. Start CG Biometric with right-click > Run as administrator.';
    case 0x80098001:
      return 'The Windows Biometric Service is not running.';
    default:
      return 'Windows Biometric error 0x${(hr & 0xFFFFFFFF).toRadixString(16).toUpperCase()}.';
  }
}

WbfCaptureResult _captureBlocking() {
  late final DynamicLibrary lib;
  try {
    lib = DynamicLibrary.open('winbio.dll');
  } catch (_) {
    return const WbfCaptureResult.fail(
      'The Windows Biometric Framework (winbio.dll) is not available on this PC.',
    );
  }

  final openSession = lib
      .lookupFunction<
        Int32 Function(
          Uint32,
          Uint32,
          Uint32,
          Pointer<Uint32>,
          IntPtr,
          Pointer<Void>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          int,
          int,
          Pointer<Uint32>,
          int,
          Pointer<Void>,
          Pointer<Uint32>,
        )
      >('WinBioOpenSession');
  final closeSession = lib
      .lookupFunction<Int32 Function(Uint32), int Function(int)>(
        'WinBioCloseSession',
      );
  final captureSample = lib
      .lookupFunction<
        Int32 Function(
          Uint32,
          Uint8,
          Uint8,
          Pointer<Uint32>,
          Pointer<Pointer<Uint8>>,
          Pointer<IntPtr>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          int,
          int,
          Pointer<Uint32>,
          Pointer<Pointer<Uint8>>,
          Pointer<IntPtr>,
          Pointer<Uint32>,
        )
      >('WinBioCaptureSample');
  final winBioFree = lib
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('WinBioFree');

  final session = calloc<Uint32>();
  final unitId = calloc<Uint32>();
  final sample = calloc<Pointer<Uint8>>();
  final sampleSize = calloc<IntPtr>();
  final reject = calloc<Uint32>();
  var opened = false;

  try {
    // Raw session = the real sensor image (needs administrator rights).
    var hr = openSession(
      _winbioTypeFingerprint,
      _winbioPoolSystem,
      _winbioFlagRaw,
      nullptr,
      0,
      nullptr,
      session,
    );
    final raw = hr == 0;
    if (!raw) {
      hr = openSession(
        _winbioTypeFingerprint,
        _winbioPoolSystem,
        _winbioFlagDefault,
        nullptr,
        0,
        nullptr,
        session,
      );
    }
    if (hr != 0) {
      return WbfCaptureResult.fail(_describe(hr), needsAdmin: _isDenied(hr));
    }
    opened = true;

    hr = captureSample(
      session.value,
      _winbioPurposeIdentify,
      raw ? _winbioDataFlagRaw : _winbioDataFlagProcessed,
      unitId,
      sample,
      sampleSize,
      reject,
    );
    if (hr != 0) {
      return WbfCaptureResult.fail(_describe(hr), needsAdmin: _isDenied(hr));
    }

    final bytes = Uint8List.fromList(
      sample.value.asTypedList(sampleSize.value),
    );
    winBioFree(sample.value.cast<Void>());

    final png = _birToPng(bytes);
    if (png != null) return WbfCaptureResult.ok(png);

    // Keep the raw sample so the format can be inspected.
    try {
      final dir = Directory(
        '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}\\CG Biometric',
      )..createSync(recursive: true);
      File('${dir.path}\\last_sample.bin').writeAsBytesSync(bytes);
    } catch (_) {}

    return WbfCaptureResult.fail(
      needsAdmin: !raw,
      raw
          ? 'The reader returned a fingerprint format this app cannot read (${bytes.length} bytes). A copy was saved in %LOCALAPPDATA%\\CG Biometric\\last_sample.bin.'
          : 'Windows only gives the fingerprint image to administrators. '
                'Close CG Biometric and start it with right-click > Run as administrator.',
    );
  } finally {
    if (opened) closeSession(session.value);
    calloc.free(session);
    calloc.free(unitId);
    calloc.free(sample);
    calloc.free(sampleSize);
    calloc.free(reject);
  }
}

/// WINBIO_BIR -> PNG.
///
/// A WINBIO_BIR starts with four {Size, Offset} blocks (header, standard data,
/// vendor data, signature). For a raw capture the standard data block is an
/// ANSI/INCITS 381 finger image record: a general header, a view header that
/// holds the width and height, then 8-bit greyscale pixels up to the end of
/// the block. Header sizes differ between drivers, so instead of trusting fixed
/// offsets this finds the width/height pair whose product equals the number of
/// pixel bytes that follow it.
Uint8List? _birToPng(Uint8List bir) {
  if (bir.length < 40) return null;
  final bd = ByteData.sublistView(bir);

  // Candidate standard-data blocks: either {Size, Offset} or {Offset, Size}.
  final candidates = <List<int>>[];
  for (final pos in const [8, 0, 16, 24]) {
    if (pos + 8 > bir.length) continue;
    final a = bd.getUint32(pos, Endian.little);
    final b = bd.getUint32(pos + 4, Endian.little);
    candidates.add([b, a]); // offset = b, size = a
    candidates.add([a, b]); // offset = a, size = b
  }
  candidates.add([0, bir.length]); // whole buffer as a last resort

  for (final c in candidates) {
    final offset = c[0];
    final size = c[1];
    if (size < 100 || offset < 0 || offset + size > bir.length) continue;
    final block = Uint8List.sublistView(bir, offset, offset + size);
    final png = _findImage(block);
    if (png != null) return png;
  }
  return null;
}

Uint8List? _findImage(Uint8List block) {
  final bd = ByteData.sublistView(block);
  final limit = block.length < 220 ? block.length - 4 : 220;
  for (var pos = 0; pos < limit; pos++) {
    for (final endian in const [Endian.big, Endian.little]) {
      final w = bd.getUint16(pos, endian);
      final h = bd.getUint16(pos + 2, endian);
      if (w < 100 || w > 1500 || h < 100 || h > 1500) continue;
      for (var gap = 0; gap <= 16; gap++) {
        final start = pos + 4 + gap;
        final remaining = block.length - start;
        if (remaining <= 0 || remaining % w != 0) continue;
        // Some drivers report a vertical size a few rows smaller than the
        // pixels they send (e.g. 360 stated, 362 sent), so accept a small range.
        final rows = remaining ~/ w;
        if (rows >= h && rows <= h + 40) {
          return _grayPng(block, start, w, rows);
        }
      }
    }
  }
  return null;
}

Uint8List _grayPng(Uint8List data, int start, int w, int h) {
  final pixels = Uint8List.fromList(data.sublist(start, start + w * h));
  final image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: pixels.buffer,
    numChannels: 1,
  );
  return Uint8List.fromList(img.encodePng(image));
}

/// Opens (but does not capture from) a Windows Biometric session, for the
/// reader diagnostics. Returns human readable lines.
Future<List<String>> probeWindowsBiometric() => Isolate.run(_probe);

List<String> _probe() {
  final lines = <String>[];
  late final DynamicLibrary lib;
  try {
    lib = DynamicLibrary.open('winbio.dll');
  } catch (_) {
    return ['winbio.dll: NOT AVAILABLE'];
  }
  final openSession = lib
      .lookupFunction<
        Int32 Function(
          Uint32,
          Uint32,
          Uint32,
          Pointer<Uint32>,
          IntPtr,
          Pointer<Void>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          int,
          int,
          Pointer<Uint32>,
          int,
          Pointer<Void>,
          Pointer<Uint32>,
        )
      >('WinBioOpenSession');
  final closeSession = lib
      .lookupFunction<Int32 Function(Uint32), int Function(int)>(
        'WinBioCloseSession',
      );

  final session = calloc<Uint32>();
  try {
    for (final entry in {
      'raw session': _winbioFlagRaw,
      'normal session': _winbioFlagDefault,
    }.entries) {
      session.value = 0;
      final hr = openSession(
        _winbioTypeFingerprint,
        _winbioPoolSystem,
        entry.value,
        nullptr,
        0,
        nullptr,
        session,
      );
      if (hr == 0) {
        lines.add('Windows Biometric ${entry.key}: OK');
        closeSession(session.value);
      } else {
        lines.add(
          'Windows Biometric ${entry.key}: FAILED - ${_describe(hr)} '
          '(0x${(hr & 0xFFFFFFFF).toRadixString(16).toUpperCase()})',
        );
      }
    }
  } finally {
    calloc.free(session);
  }
  return lines;
}
