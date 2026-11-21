import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/web/script_loader.dart';
import 'package:sat_east_client/features/teacher/videos/data/services/ffmpeg_core_integrity.dart';
import 'package:sat_east_client/features/teacher/videos/data/services/ffmpeg_hls.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/domain/services/video_transcoder.dart';
import 'package:web/web.dart' as web;

// The @ffmpeg/ffmpeg wrapper is pinned and self-hosted under web/vendor/. The
// 32 MB core (over Cloudflare Pages' 25 MiB file limit) is loaded from a
// version-pinned jsDelivr URL and SHA-256 checked before use. Single-thread
// build: no COOP/COEP.
const _ffmpegScript = 'vendor/ffmpeg-0.12.15/ffmpeg.js';
const _mountDir = '/in';
const _metadataTimeout = Duration(seconds: 15);

VideoTranscoder createVideoTranscoder() => WebVideoTranscoder();

/// `new FFmpegWASM.FFmpeg()` from @ffmpeg/ffmpeg 0.12.15 (UMD global).
@JS('FFmpegWASM.FFmpeg')
extension type FfmpegJs._(JSObject _) implements JSObject {
  external factory FfmpegJs();
  external JSPromise<JSBoolean> load(JSObject config);
  external JSPromise<JSBoolean> createDir(String path);
  external JSPromise<JSBoolean> mount(
    String fsType,
    JSObject options,
    String mountPoint,
  );
  external JSPromise<JSBoolean> writeFile(String path, JSAny data);
  external JSPromise<JSNumber> exec(JSArray<JSString> args);
  external JSPromise<JSArray<FfmpegDirNode>> listDir(String path);
  external JSPromise<JSAny> readFile(String path);
  external void on(String event, JSFunction callback);
  external void terminate();
}

extension type FfmpegDirNode._(JSObject _) implements JSObject {
  external String get name;
  external bool get isDir;
}

extension type FfmpegLogEvent._(JSObject _) implements JSObject {
  external String get message;
}

extension type FfmpegProgressEvent._(JSObject _) implements JSObject {
  external double get progress;
}

/// 540p AES-128 HLS in the browser via ffmpeg.wasm. The 32 MB core is only
/// fetched by [transcode], never at app start. One instance per upload.
class WebVideoTranscoder implements VideoTranscoder {
  final _progress = StreamController<double>.broadcast();
  FfmpegJs? _ffmpeg;
  bool _cancelled = false;
  bool _collectLogs = false;
  final _logs = <String>[];
  final _blobUrls = <String>[];

  static const _cancelledFailure = Failure<TranscodedVideo>(
    AppError(ErrorCodes.cancelled),
  );
  static const _failed = Failure<TranscodedVideo>(
    AppError(ErrorCodes.videoTranscodeFailed),
  );
  static const _engineFailed = Failure<TranscodedVideo>(
    AppError(ErrorCodes.videoEngineLoadFailed),
  );

  @override
  bool get isSupported => true;

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Future<void> cancel() async {
    _cancelled = true;
    // Rejects every pending ffmpeg promise; transcode() maps that to cancelled.
    _ffmpeg?.terminate();
  }

  @override
  Future<Result<int>> probeDuration(PickedVideo source) async {
    final file = _asFile(source.handle);
    if (file == null) return const Failure(AppError(ErrorCodes.internal));
    final url = web.URL.createObjectURL(file);
    final video = web.HTMLVideoElement()
      ..preload = 'metadata'
      ..muted = true;
    final done = Completer<Result<int>>();
    void finish(Result<int> value) {
      if (!done.isCompleted) done.complete(value);
    }

    final loaded = ((web.Event _) {
      final seconds = video.duration;
      finish(
        seconds.isFinite && seconds > 0
            ? Success(seconds.ceil())
            : const Failure(AppError(ErrorCodes.internal)),
      );
    }).toJS;
    final failed = ((web.Event _) => finish(
      const Failure(AppError(ErrorCodes.internal)),
    )).toJS;
    video
      ..addEventListener('loadedmetadata', loaded)
      ..addEventListener('error', failed)
      ..src = url;
    try {
      return await done.future.timeout(
        _metadataTimeout,
        onTimeout: () => const Failure(AppError(ErrorCodes.internal)),
      );
    } finally {
      video
        ..removeEventListener('loadedmetadata', loaded)
        ..removeEventListener('error', failed)
        ..removeAttribute('src')
        ..load();
      web.URL.revokeObjectURL(url);
    }
  }

  @override
  Future<Result<TranscodedVideo>> transcode(
    PickedVideo source,
    Uint8List key,
  ) async {
    final file = _asFile(source.handle);
    if (file == null) return const Failure(AppError(ErrorCodes.internal));
    try {
      return await _transcode(file, source.name, key);
    } on Object {
      return _cancelled ? _cancelledFailure : _failed;
    } finally {
      _revokeBlobUrls();
      _ffmpeg?.terminate();
      _ffmpeg = null;
      // One instance per upload: transcode runs once, so progress is done.
      if (!_progress.isClosed) unawaited(_progress.close());
    }
  }

  void _revokeBlobUrls() {
    // dart2js disallows tear-offs of interop members, so no forEach.
    // ignore: prefer_foreach
    for (final url in _blobUrls) {
      web.URL.revokeObjectURL(url);
    }
    _blobUrls.clear();
  }

  /// Fetches [url], checks its SHA-256 against [sha256Hex] and returns a blob
  /// URL for it, or null on a network failure or a hash mismatch.
  Future<String?> _verifiedBlobUrl(
    String url,
    String sha256Hex,
    String mimeType,
  ) async {
    try {
      final response = await web.window.fetch(url.toJS).toDart;
      if (!response.ok) return null;
      final buffer = (await response.arrayBuffer().toDart).toDart;
      final bytes = buffer.asUint8List();
      final raw = await web.window.crypto.subtle
          .digest('SHA-256'.toJS, bytes.toJS)
          .toDart;
      final digest = (raw! as JSArrayBuffer).toDart.asUint8List();
      if (!digestMatches(digest, sha256Hex)) return null;
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      return web.URL.createObjectURL(blob);
    } on Object {
      return null;
    }
  }

  Future<Result<TranscodedVideo>> _transcode(
    web.File file,
    String name,
    Uint8List key,
  ) async {
    await loadScript(_ffmpegScript);
    if (_cancelled) return _cancelledFailure;
    final ffmpeg = _ffmpeg = FfmpegJs()
      ..on(
        'log',
        ((FfmpegLogEvent event) {
          if (_collectLogs) _logs.add(event.message);
        }).toJS,
      )
      ..on(
        'progress',
        ((FfmpegProgressEvent event) {
          final value = event.progress;
          if (value.isFinite && !_progress.isClosed) {
            _progress.add(value.clamp(0.0, 1.0));
          }
        }).toJS,
      );
    final coreJsUrl = await _verifiedBlobUrl(
      ffmpegCoreJsUrl,
      ffmpegCoreJsSha256,
      'text/javascript',
    );
    if (coreJsUrl == null) return _engineFailed;
    _blobUrls.add(coreJsUrl);
    final coreWasmUrl = await _verifiedBlobUrl(
      ffmpegCoreWasmUrl,
      ffmpegCoreWasmSha256,
      'application/wasm',
    );
    if (coreWasmUrl == null) return _engineFailed;
    _blobUrls.add(coreWasmUrl);
    try {
      await ffmpeg
          .load(
            {'coreURL': coreJsUrl, 'wasmURL': coreWasmUrl}.jsify()! as JSObject,
          )
          .toDart;
    } on Object {
      if (_cancelled) return _cancelledFailure;
      return _engineFailed;
    } finally {
      _revokeBlobUrls();
    }
    if (_cancelled) return _cancelledFailure;

    // WORKERFS reads the browser File lazily: the source is never copied
    // into wasm memory. The name is fixed so odd characters in the teacher's
    // file name cannot be taken for an ffmpeg protocol or option.
    final input = '$_mountDir/${_sourceName(name)}';
    await ffmpeg.createDir(_mountDir).toDart;
    await ffmpeg.createDir(ffmpegOutDir).toDart;
    await ffmpeg
        .mount(
          'WORKERFS',
          {
                'blobs': [
                  {'name': _sourceName(name), 'data': file},
                ],
              }.jsify()!
              as JSObject,
          _mountDir,
        )
        .toDart;
    // writeFile transfers (detaches) the buffer it is given: pass a copy.
    // Best effort: the copy is zeroed afterwards, but the hex string held by
    // the caller and ffmpeg's own copy of the key file are out of reach.
    final keyCopy = Uint8List.fromList(key);
    try {
      await ffmpeg.writeFile(ffmpegKeyPath, keyCopy.toJS).toDart;
    } finally {
      keyCopy.fillRange(0, keyCopy.length, 0);
    }
    await ffmpeg.writeFile(ffmpegKeyInfoPath, ffmpegKeyInfo.toJS).toDart;
    if (_cancelled) return _cancelledFailure;

    // ffprobe equivalent: `ffmpeg -i` exits non-zero by design.
    _collectLogs = true;
    await ffmpeg.exec(_args(ffmpegProbeArgs(input))).toDart;
    _collectLogs = false;
    final probe = parseFfmpegProbe(_logs);
    if (!probe.hasVideo) return _failed;

    final code = await ffmpeg
        .exec(_args(ffmpegHlsArgs(input: input, audio: probe.hasAudio)))
        .toDart;
    if (_cancelled) return _cancelledFailure;
    if (code.toDartInt != 0) return _failed;

    final nodes = (await ffmpeg.listDir(ffmpegOutDir).toDart).toDart;
    final files = <HlsFile>[];
    for (final node in nodes.where((n) => !n.isDir)) {
      final data = await ffmpeg.readFile('$ffmpegOutDir/${node.name}').toDart;
      if (!data.isA<JSUint8Array>()) return _failed;
      files.add(HlsFile(name: node.name, bytes: (data as JSUint8Array).toDart));
    }
    if (files.isEmpty) return _failed;
    final durationS = probe.durationS ?? _playlistDuration(files);
    if (durationS == null) return _failed;
    return Success(TranscodedVideo(files: files, durationS: durationS));
  }
}

/// The picker's opaque handle, when it is a browser `File`.
web.File? _asFile(Object handle) {
  final js = handle.jsify();
  return js != null && js.isA<web.File>() ? js as web.File : null;
}

JSArray<JSString> _args(List<String> args) =>
    args.map((a) => a.toJS).toList().toJS;

/// Keeps a short, safe extension so format probing behaves as for a file.
String _sourceName(String original) {
  final dot = original.lastIndexOf('.');
  final ext = dot < 0 ? '' : original.substring(dot);
  return RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(ext)
      ? 'source$ext'
      : 'source';
}

int? _playlistDuration(List<HlsFile> files) {
  for (final file in files) {
    if (file.name == '540p.m3u8') {
      return hlsPlaylistDurationS(utf8.decode(file.bytes));
    }
  }
  return null;
}
