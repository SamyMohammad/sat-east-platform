import 'package:flutter/foundation.dart';
import 'package:sat_east_client/features/auth/data/datasources/user_agent_stub.dart'
    if (dart.library.js_interop) 'package:sat_east_client/features/auth/data/datasources/user_agent_web.dart';

const _maxLabelLength = 80;

/// Platform and human label sent to `register_device`.
class DeviceInfo {
  const DeviceInfo();

  /// One of `web|android|ios`.
  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  String get label {
    final raw = kIsWeb
        ? labelFromUserAgent(readUserAgent())
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'Android app',
            TargetPlatform.iOS => 'iOS app',
            _ => 'Web browser',
          };
    return truncateLabel(raw);
  }
}

/// Parses a user agent into "Browser on OS", or "Web browser" if unknown.
String labelFromUserAgent(String ua) {
  // Order matters: Edge UAs also contain "Chrome" and "Safari".
  final browser = switch (ua) {
    _ when ua.contains('Edg') => 'Edge',
    _ when ua.contains('OPR/') || ua.contains('Opera') => 'Opera',
    _ when ua.contains('Firefox') || ua.contains('FxiOS') => 'Firefox',
    _ when ua.contains('Chrome') || ua.contains('CriOS') => 'Chrome',
    _ when ua.contains('Safari') => 'Safari',
    _ => null,
  };
  if (browser == null) return 'Web browser';

  // iOS UAs also contain "Mac OS X"; Android UAs also contain "Linux".
  final os = switch (ua) {
    _ when ua.contains('iPhone') || ua.contains('iPad') => 'iOS',
    _ when ua.contains('Android') => 'Android',
    _ when ua.contains('Windows') => 'Windows',
    _ when ua.contains('Macintosh') || ua.contains('Mac OS X') => 'macOS',
    _ when ua.contains('Linux') || ua.contains('X11') => 'Linux',
    _ => null,
  };
  return os == null ? browser : '$browser on $os';
}

String truncateLabel(String label) => label.length <= _maxLabelLength
    ? label
    : label.substring(0, _maxLabelLength);
