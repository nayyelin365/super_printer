import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/timer/domain/kitchen_timer.dart';

void main() {
  group('KitchenTimer', () {
    test('running timer counts down live from endAt', () {
      final timer = KitchenTimer(
        id: 't1',
        label: 'Rice',
        totalDuration: const Duration(minutes: 5),
        endAt: DateTime.now().add(const Duration(seconds: 90)),
      );
      expect(timer.isRunning, isTrue);
      expect(timer.isPaused, isFalse);
      expect(timer.remaining.inSeconds, closeTo(90, 2));
      expect(timer.remainingLabel, matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('paused timer reports its frozen remaining time', () {
      const timer = KitchenTimer(
        id: 't2',
        label: 'Timer',
        totalDuration: Duration(minutes: 10),
        pausedRemaining: Duration(minutes: 3, seconds: 30),
      );
      expect(timer.isRunning, isFalse);
      expect(timer.isPaused, isTrue);
      expect(timer.remaining, const Duration(minutes: 3, seconds: 30));
      expect(timer.remainingLabel, '03:30');
    });

    test('finished timer reports zero remaining and is neither running nor paused', () {
      // Matches the real invariant (see TimerController._tick): a timer is
      // marked finished only once its endAt is cleared.
      const timer = KitchenTimer(
        id: 't3',
        label: 'Timer',
        totalDuration: Duration(minutes: 1),
        isFinished: true,
      );
      expect(timer.remaining, Duration.zero);
      expect(timer.isRunning, isFalse);
      expect(timer.isPaused, isFalse);
    });

    test('remainingLabel includes hours only when >= 1 hour left', () {
      final short = KitchenTimer(
        id: 't4',
        label: 'Timer',
        totalDuration: const Duration(minutes: 5),
        pausedRemaining: const Duration(minutes: 4, seconds: 5),
      );
      final long = KitchenTimer(
        id: 't5',
        label: 'Timer',
        totalDuration: const Duration(hours: 2),
        pausedRemaining: const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(short.remainingLabel, '04:05');
      expect(long.remainingLabel, '1:02:03');
    });

    test('copyWith clearing endAt/notificationId via function wrappers sets null', () {
      final running = KitchenTimer(
        id: 't6',
        label: 'Timer',
        totalDuration: const Duration(minutes: 1),
        endAt: DateTime.now().add(const Duration(minutes: 1)),
        notificationId: 42,
      );
      final paused = running.copyWith(
        endAt: () => null,
        pausedRemaining: () => const Duration(seconds: 30),
        notificationId: () => null,
      );
      expect(paused.endAt, isNull);
      expect(paused.notificationId, isNull);
      expect(paused.pausedRemaining, const Duration(seconds: 30));
      expect(paused.isPaused, isTrue);
    });
  });
}
