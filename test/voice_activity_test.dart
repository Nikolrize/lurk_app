import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/services/voice_activity_tracker.dart';

void main() {
  test('separate local and remote callbacks preserve both speakers', () {
    final tracker = VoiceActivityTracker();
    final now = DateTime.utc(2026, 10, 31);
    tracker.update({42: 80}, now);
    tracker.update({0: 50}, now.add(const Duration(milliseconds: 20)));
    expect(tracker.activeAt(now.add(const Duration(milliseconds: 30))), {
      0,
      42,
    });
    tracker.update({0: 0}, now.add(const Duration(milliseconds: 40)));
    tracker.update({}, now.add(const Duration(milliseconds: 50)));
    expect(tracker.activeAt(now.add(const Duration(milliseconds: 60))), {42});
    tracker.update({42: 0}, now.add(const Duration(milliseconds: 70)));
    expect(
      tracker.activeAt(now.add(const Duration(milliseconds: 80))),
      isEmpty,
    );
  });

  test(
    'missing callbacks expire speakers independently; leaving clears activity',
    () {
      final tracker = VoiceActivityTracker();
      final now = DateTime.utc(2026, 10, 31);
      tracker.update({42: 80, 7: 50}, now);
      tracker.update({0: 60}, now.add(const Duration(milliseconds: 500)));
      expect(tracker.activeAt(now.add(const Duration(milliseconds: 710))), {0});
      tracker.remove(0);
      expect(
        tracker.activeAt(now.add(const Duration(milliseconds: 720))),
        isEmpty,
      );
      tracker.update({42: 60}, now.add(const Duration(milliseconds: 800)));
      tracker.clear();
      expect(
        tracker.activeAt(now.add(const Duration(milliseconds: 810))),
        isEmpty,
      );
    },
  );
}
