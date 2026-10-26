import 'package:sat_east_client/core/errors/error_codes.dart';

abstract final class VideoCopy {
  static const title = 'Video';
  static const retry = 'Retry';
  static const play = 'Play';
  static const pause = 'Pause';
  static const speed = 'Playback speed';
  static const seek = 'Playback position';
  static const fullscreen = 'Full screen';
  static const exitFullscreen = 'Exit full screen';
  static const back = 'Back to topic';
  static const loading = 'Loading video';
  static const speeds = <(double, String)>[
    (1, '1\u00d7'),
    (1.25, '1.25\u00d7'),
    (1.5, '1.5\u00d7'),
  ];

  static String speedLabel(double rate) => speeds
      .firstWhere(
        (entry) => entry.$1 == rate,
        orElse: () => speeds.first,
      )
      .$2;

  static String time(double seconds) {
    final s = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String error(String code) => switch (code) {
    ErrorCodes.videoNeeded ||
    ErrorCodes.topicLocked => "This video isn't open yet.",
    ErrorCodes.notEnrolled ||
    ErrorCodes.accessExpired => 'Your access to this course has ended.',
    ErrorCodes.deviceRevoked => 'This device was signed out. Sign in again.',
    ErrorCodes.rateLimited => 'Too many tries. Wait a minute and retry.',
    ErrorCodes.unsupported => 'Video plays in the web app for now.',
    _ => "Couldn't load the video. Try again.",
  };
}
