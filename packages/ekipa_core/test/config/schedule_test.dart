import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

SlotSchedule _schedule({
  String weekdays = '4,5,6',
  String startTimes = '16:00,17:30,19:00',
  Duration duration = const Duration(minutes: 90),
}) => SlotSchedule.parse(
  weekdays: weekdays,
  startTimes: startTimes,
  duration: duration,
).valueOrNull!;

String _error({
  String weekdays = '4,5,6',
  String startTimes = '16:00,17:30,19:00',
  Duration duration = const Duration(minutes: 90),
}) => SlotSchedule.parse(
  weekdays: weekdays,
  startTimes: startTimes,
  duration: duration,
).errorOrNull!;

void main() {
  group('LocalTime', () {
    test('parses what a schedule is written in', () {
      expect(LocalTime.tryParse('17:30'), const LocalTime(17, 30));
      expect(LocalTime.tryParse('9:05'), const LocalTime(9, 5));
    });

    test('refuses what is not a time', () {
      for (final text in ['17', '17:30:00', '25:00', '17:60', '', 'ten']) {
        expect(
          LocalTime.tryParse(text),
          isNull,
          reason: '"$text" must not parse',
        );
      }
    });

    test('formats for Postgres and for a person differently', () {
      expect(const LocalTime(9, 5).sqlLiteral, '09:05:00');
      expect(const LocalTime(9, 5).toString(), '09:05');
    });

    test('orders by time of day', () {
      final times = [
        const LocalTime(19, 0),
        const LocalTime(16, 0),
        const LocalTime(17, 30),
      ]..sort();
      expect(times.map((time) => time.toString()), ['16:00', '17:30', '19:00']);
    });
  });

  group('parsing a schedule', () {
    test('accepts the locked Osijek week', () {
      final schedule = _schedule();
      expect(schedule.weekdays, [4, 5, 6]);
      expect(schedule.startTimes.map((time) => time.toString()), [
        '16:00',
        '17:30',
        '19:00',
      ]);
      expect(schedule.slotsPerWeek, 9);
    });

    test('sorts whatever order it was given', () {
      final schedule = _schedule(
        weekdays: '6,4,5',
        startTimes: '19:00,16:00,17:30',
      );
      expect(schedule.weekdays, [4, 5, 6]);
      expect(schedule.startTimes.first, const LocalTime(16, 0));
    });

    test('refuses start times closer together than a slot is long', () {
      // The failure this prevents is a person truthfully available for two
      // overlapping slots and placed in both — a group waiting for somebody
      // who is at another table.
      final message = _error(startTimes: '16:00,17:00');
      expect(message, contains('overlap'));
      expect(message, contains('60 minutes apart'));
    });

    test('a gap exactly one slot long is allowed', () {
      expect(_schedule(startTimes: '16:00,17:30').slotsPerWeek, 6);
    });

    test('refuses a weekday outside 1-7', () {
      expect(_error(weekdays: '0'), contains('ISO weekday'));
      expect(_error(weekdays: '8'), contains('ISO weekday'));
      expect(_error(weekdays: 'Thursday'), contains('ISO weekday'));
    });

    test('refuses a repeated weekday or start time', () {
      expect(_error(weekdays: '4,4'), contains('twice'));
      expect(_error(startTimes: '16:00,16:00'), contains('twice'));
    });

    test('refuses an empty list rather than generating an empty week', () {
      expect(_error(weekdays: ''), contains('at least one evening'));
      expect(_error(startTimes: ''), contains('at least one start time'));
    });

    test('refuses a slot with no length', () {
      expect(_error(duration: Duration.zero), contains('positive'));
    });

    test('reads itself out of a config snapshot', () {
      final schedule = SlotSchedule.fromSnapshot(
        ConfigSnapshot.defaults(),
      ).valueOrNull!;
      expect(schedule.slotsPerWeek, 9);
      expect(schedule.duration, const Duration(minutes: 90));
    });

    test(
      'a snapshot with a broken schedule reports it rather than throwing',
      () {
        final broken = ConfigSnapshot(
          versionId: const ConfigVersionId('v2'),
          values: {ScheduleKeys.weekdays.name: '4,5,9'},
        );
        expect(SlotSchedule.fromSnapshot(broken).isErr, isTrue);
      },
    );
  });

  group('materialising', () {
    test('emits every start time on every configured weekday', () {
      // 2026-08-17 is a Monday, so a full week from it contains one Thursday,
      // one Friday and one Saturday.
      final slots = _schedule().materialise(
        from: DateTime.utc(2026, 8, 17),
        weeks: 1,
      );

      expect(slots, hasLength(9));
      expect(slots.map((slot) => slot.weekday).toSet(), {4, 5, 6});
      expect(slots.first.sqlDate, '2026-08-20');
      expect(slots.first.startsAt, const LocalTime(16, 0));
    });

    test('two weeks is twice one week', () {
      final schedule = _schedule();
      final from = DateTime.utc(2026, 8, 17);
      expect(
        schedule.materialise(from: from, weeks: 2),
        hasLength(schedule.materialise(from: from, weeks: 1).length * 2),
      );
    });

    test('a horizon of zero weeks produces nothing, not an error', () {
      expect(
        _schedule().materialise(from: DateTime.utc(2026, 8, 17), weeks: 0),
        isEmpty,
      );
    });

    test('the window starts on the given day, inclusive', () {
      // Starting on a Thursday must not skip that Thursday.
      final slots = _schedule().materialise(
        from: DateTime.utc(2026, 8, 20),
        weeks: 1,
      );
      expect(slots.first.sqlDate, '2026-08-20');
    });

    test('the time and zone of the from-date are ignored', () {
      final atNoon = _schedule().materialise(
        from: DateTime.utc(2026, 8, 17, 12, 34),
        weeks: 1,
      );
      final atMidnight = _schedule().materialise(
        from: DateTime.utc(2026, 8, 17),
        weeks: 1,
      );
      expect(atNoon, atMidnight);
    });

    test('it crosses a month boundary without arithmetic of its own', () {
      final slots = _schedule().materialise(
        from: DateTime.utc(2026, 8, 31),
        weeks: 1,
      );
      expect(slots.map((slot) => slot.sqlDate).toSet(), {
        '2026-09-03',
        '2026-09-04',
        '2026-09-05',
      });
    });

    test('no two slots on the same day overlap', () {
      final slots = _schedule().materialise(
        from: DateTime.utc(2026, 8, 17),
        weeks: 2,
      );
      for (var i = 0; i < slots.length; i++) {
        for (var j = i + 1; j < slots.length; j++) {
          expect(
            slots[i].overlaps(slots[j]),
            isFalse,
            reason: '${slots[i]} overlaps ${slots[j]}',
          );
        }
      }
    });

    test('the same start time on two dates does not count as an overlap', () {
      final thursday = _schedule()
          .materialise(
            from: DateTime.utc(2026, 8, 20),
            weeks: 1,
          )
          .first;
      final friday = _schedule()
          .materialise(
            from: DateTime.utc(2026, 8, 21),
            weeks: 1,
          )
          .first;

      expect(thursday.startsAt, friday.startsAt);
      expect(thursday.overlaps(friday), isFalse);
    });

    test('dates format the way Postgres reads them', () {
      final slot = _schedule(
        weekdays: '3',
      ).materialise(from: DateTime.utc(2026, 8, 31), weeks: 1).first;
      expect(slot.sqlDate, '2026-09-02');
      expect(slot.startsAt.sqlLiteral, '16:00:00');
    });
  });

  group('the signature', () {
    test('identifies which schedule produced a slot row', () {
      expect(_schedule().signature, 'schedule:4,5,6@16:00,17:30,19:00/90m');
    });

    test('two schedules that differ have different signatures', () {
      expect(
        _schedule(weekdays: '4,5').signature,
        isNot(_schedule().signature),
      );
      expect(
        _schedule(
          startTimes: '16:00',
          duration: const Duration(minutes: 120),
        ).signature,
        isNot(_schedule().signature),
      );
    });

    test('input order does not change it', () {
      expect(_schedule(weekdays: '6,5,4').signature, _schedule().signature);
    });
  });
}
