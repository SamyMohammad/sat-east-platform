enum VideoProvider {
  r2Hls,
  youtube;

  static VideoProvider fromWire(String value) => switch (value) {
    'r2_hls' => r2Hls,
    'youtube' => youtube,
    _ => throw const FormatException('video provider'),
  };
}
