import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_quota.dart';

void main() {
  test('C-2: quota label uses configured storage cap in GB', () {
    const quota = VideoQuota(usedMb: 3277, capMb: 9216);
    expect(quota.label, '3.2 of 9 GB used');
  });
}
