import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';

void main() {
  for (final (used, label) in [
    (0, '0 MB of 9 GB used'),
    (28, '28 MB of 9 GB used'),
    (1023, '1023 MB of 9 GB used'),
    (1024, '1.0 of 9 GB used'),
  ]) {
    test('C-2: quota label at $used MB', () {
      expect(VideoQuota(usedMb: used, capMb: 9216).label, label);
    });
  }
  test('C-2: quota label uses configured storage cap in GB', () {
    const quota = VideoQuota(usedMb: 3277, capMb: 9216);
    expect(quota.label, '3.2 of 9 GB used');
  });
}
