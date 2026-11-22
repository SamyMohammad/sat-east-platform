// Platform factory: ffmpeg.wasm on web, an unsupported stub elsewhere.
export 'video_transcoder_stub.dart'
    if (dart.library.js_interop) 'video_transcoder_web.dart';
