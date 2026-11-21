enum VideoProvider {
  r2Hls;

  static VideoProvider fromWire(String value) => switch (value) {
    'r2_hls' => r2Hls,
    _ => throw const FormatException('video provider'),
  };
}
