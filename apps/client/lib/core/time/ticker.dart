typedef Ticker = Stream<void> Function(Duration period);

Stream<void> defaultTicker(Duration period) => Stream<void>.periodic(period);
