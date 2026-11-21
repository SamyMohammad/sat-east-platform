import 'dart:typed_data';

// @ffmpeg/core 0.12.10 (single-thread UMD build), pinned by version and
// SHA-256. Both files are byte-identical to the upstream npm release.
const ffmpegCoreJsUrl =
    'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd/ffmpeg-core.js';
const ffmpegCoreJsSha256 =
    'b266ab5b952555881dd6310663986994a182acb2b7ff25cf10a25f7a37ac2b21';
const ffmpegCoreWasmUrl =
    'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd/ffmpeg-core.wasm';
const ffmpegCoreWasmSha256 =
    '9f57947a5bd530d8f00c5b3f2cb2a3492faa7e5d823315342d6a8656d0a6b7b7';

/// Lowercase hex of [bytes], two digits per byte.
String hexOf(Uint8List bytes) {
  final out = StringBuffer();
  for (final byte in bytes) {
    out.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

/// Whether the SHA-256 [digest] equals [expectedHex] (case-insensitive).
bool digestMatches(Uint8List digest, String expectedHex) =>
    hexOf(digest) == expectedHex.toLowerCase();
