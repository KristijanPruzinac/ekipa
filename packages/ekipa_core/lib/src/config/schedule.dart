import 'package:ekipa_core/src/config/catalogue.dart';
import 'package:ekipa_core/src/foundation/config.dart';
import 'package:ekipa_core/src/foundation/result.dart';
import 'package:meta/meta.dart';

/// A wall-clock time of day, with no date and no zone.
///
/// **Intention.** "17:30" in a city is a local human concept and stays one
/// until the moment it is materialised. Modelling it as a `DateTime` would
/// attach a date and a zone to a value that has neither, and the attached zone
/// is always wrong — it is whatever the machine running the generator happens
/// to be set to.
@immutable
final class LocalTime implements Comparable<LocalTime> {
  /// A time of day.
  const LocalTime(this.hour, this.minute);

  /// Parses `HH:mm`, returning `null` if [text] is not one.
  static LocalTime? tryParse(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return LocalTime(hour, minute);
  }

  /// The hour, 0–23.
  final int hour;

  /// The minute, 0–59.
  final int minute;

  /// Minutes since local midnight.
  int get minutesFromMidnight => hour * 60 + minute;

  /// The `time` literal Postgres stores in `slots.local_time`.
  String get sqlLiteral => '${_pad(hour)}:${_pad(minute)}:00';

  static String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  int compareTo(LocalTime other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTime && other.hour == hour && other.minute == minute);

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => '${_pad(hour)}:${_pad(minute)}';
}

/// One slot as the schedule describes it: a local date, a local time and a
/// length. **Not an instant.**
///
/// **Intention.** This is the boundary between the two systems that each own
/// half of the answer. Which Thursdays exist, and what happens at 17:30, is
/// calendar arithmetic — pure, testable, and here. Turning
/// `(2026-10-25, 17:30, Europe/Zagreb)` into a UTC instant needs the tz
/// database, which Postgres ships and Dart does not.
///
/// **Rejected — transcribing the EU daylight-saving rule into `ekipa_core`.**
/// It is twenty lines and it would be right today. It is also a second copy of
/// a database that updates without us, in a country that has been debating
/// abolishing the switch for years, and the failure mode is an hour of four
/// people standing outside a bar on the last Sunday in October.
///
/// **Rejected — `package:timezone` in `ekipa_core`.** SC-2's bar is highest
/// here: every dependency in this package compiles into four runtimes, and it
/// would buy a conversion that happens in exactly one place, at the moment of
/// materialisation, on the machine that already has tzdata loaded.
@immutable
final class LocalSlot {
  /// Describes one slot in local terms.
  const LocalSlot({
    required this.year,
    required this.month,
    required this.day,
    required this.weekday,
    required this.startsAt,
    required this.duration,
  });

  /// Calendar year.
  final int year;

  /// Calendar month, 1–12.
  final int month;

  /// Day of month.
  final int day;

  /// ISO weekday, 1 (Monday) – 7 (Sunday). Matches the `local_weekday` check
  /// constraint on `public.slots`.
  final int weekday;

  /// Local start time.
  final LocalTime startsAt;

  /// How long it runs.
  final Duration duration;

  /// The `date` literal Postgres stores in `slots.local_date`.
  String get sqlDate => '$year-${LocalTime._pad(month)}-${LocalTime._pad(day)}';

  /// Whether this slot's window overlaps [other]'s on the same day.
  bool overlaps(LocalSlot other) {
    if (sqlDate != other.sqlDate) return false;
    final start = startsAt.minutesFromMidnight;
    final end = start + duration.inMinutes;
    final otherStart = other.startsAt.minutesFromMidnight;
    final otherEnd = otherStart + other.duration.inMinutes;
    return start < otherEnd && otherStart < end;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSlot &&
          other.sqlDate == sqlDate &&
          other.startsAt == startsAt &&
          other.duration == duration);

  @override
  int get hashCode => Object.hash(sqlDate, startsAt, duration);

  @override
  String toString() => 'LocalSlot($sqlDate $startsAt +${duration.inMinutes}m)';
}

/// The recurring shape of a city's week.
@immutable
final class SlotSchedule {
  const SlotSchedule._(this.weekdays, this.startTimes, this.duration);

  /// Reads a schedule out of a resolved snapshot.
  ///
  /// The weekday and start-time lists are stored as text (`4,5,6` and
  /// `16:00,17:30,19:00`) because a config value is one JSON scalar per key and
  /// three weekdays are not three keys — `schedule.weekday_1` cannot express
  /// "this city runs one evening a week" without a null nobody validates.
  static Result<SlotSchedule, String> fromSnapshot(ConfigSnapshot snapshot) =>
      parse(
        weekdays: snapshot.get(ScheduleKeys.weekdays),
        startTimes: snapshot.get(ScheduleKeys.startTimes),
        duration: snapshot.get(ScheduleKeys.slotDuration),
      );

  /// Parses and validates a schedule.
  static Result<SlotSchedule, String> parse({
    required String weekdays,
    required String startTimes,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) {
      return const Err('A slot must have a positive length.');
    }

    // Checked before splitting: `''.split(',')` yields one empty field, so a
    // blank list would otherwise be reported as a malformed weekday, which
    // sends the reader looking for a typo that is not there.
    if (weekdays.trim().isEmpty) {
      return const Err('A city needs at least one evening.');
    }
    if (startTimes.trim().isEmpty) {
      return const Err('A day needs at least one start time.');
    }

    final days = <int>{};
    for (final field in weekdays.split(',')) {
      final day = int.tryParse(field.trim());
      if (day == null || day < 1 || day > 7) {
        return Err('"$field" is not an ISO weekday (1 = Monday, 7 = Sunday).');
      }
      if (!days.add(day)) return Err('Weekday $day is listed twice.');
    }
    final times = <LocalTime>[];
    for (final field in startTimes.split(',')) {
      final time = LocalTime.tryParse(field.trim());
      if (time == null) return Err('"$field" is not a time of day (HH:mm).');
      if (times.contains(time)) return Err('$time is listed twice.');
      times.add(time);
    }
    times.sort();
    // Two start times closer together than a slot is long means one person can
    // truthfully claim both and be placed in two hangouts at once. The matcher
    // already refuses overlapping placements (`Slot.overlaps`); this refuses
    // the schedule that makes the situation possible in the first place, which
    // is the cheaper place to catch it by a wide margin.
    for (var i = 1; i < times.length; i++) {
      final gap =
          times[i].minutesFromMidnight - times[i - 1].minutesFromMidnight;
      if (gap < duration.inMinutes) {
        return Err(
          '${times[i - 1]} and ${times[i]} are $gap minutes apart, closer '
          'than the ${duration.inMinutes}-minute slot they start. They would '
          'overlap, and one person could be available for both.',
        );
      }
    }

    final sortedDays = days.toList()..sort();
    return Ok(
      SlotSchedule._(
        List.unmodifiable(sortedDays),
        List.unmodifiable(times),
        duration,
      ),
    );
  }

  /// ISO weekdays the city runs, ascending.
  final List<int> weekdays;

  /// Local start times, ascending.
  final List<LocalTime> startTimes;

  /// How long each slot runs.
  final Duration duration;

  /// How many slots a full week produces.
  int get slotsPerWeek => weekdays.length * startTimes.length;

  /// A stable description of this schedule, written to `slots.generated_by`.
  ///
  /// It is what lets someone looking at a slot row a month later say which
  /// schedule produced it, without joining anything. A slot generated under a
  /// schedule that has since changed is otherwise indistinguishable from one
  /// generated under the current schedule and simply wrong.
  String get signature =>
      'schedule:${weekdays.join(",")}@${startTimes.join(",")}'
      '/${duration.inMinutes}m';

  /// Materialises every slot from [from] (inclusive) for [weeks] weeks.
  ///
  /// [from] is read as a **local** calendar date; its time and zone are
  /// ignored. Passing a UTC `DateTime` here is normal and correct — the value
  /// is being used as a date, not as an instant.
  List<LocalSlot> materialise({required DateTime from, required int weeks}) {
    if (weeks <= 0) return const [];
    final slots = <LocalSlot>[];
    final start = DateTime.utc(from.year, from.month, from.day);

    for (var offset = 0; offset < weeks * 7; offset++) {
      final day = start.add(Duration(days: offset));
      if (!weekdays.contains(day.weekday)) continue;
      for (final time in startTimes) {
        slots.add(
          LocalSlot(
            year: day.year,
            month: day.month,
            day: day.day,
            weekday: day.weekday,
            startsAt: time,
            duration: duration,
          ),
        );
      }
    }
    return slots;
  }
}

/// The keys that describe a city's week.
///
/// Config rather than a table: `01_ARCHITECTURE.md` §5 names this as the
/// example that justifies scoping at all — *Osijek can run three weekdays while
/// a new city runs one, without a code path*. A schedule table would need its
/// own versioning, its own effective-from and its own audit trail, all of which
/// `config_versions` already has.
abstract final class ScheduleKeys {
  /// Which evenings the city runs, as ISO weekdays.
  static final ConfigKey<String> weekdays = ConfigKey.text(
    'schedule.weekdays',
    defaultValue: '4,5,6',
    description:
        'ISO weekdays the city runs, comma-separated (1 = Monday). Thursday, '
        'Friday and Saturday by default: the evenings people already go out.',
  );

  /// When slots start, local time.
  static final ConfigKey<String> startTimes = ConfigKey.text(
    'schedule.start_times',
    defaultValue: '16:00,17:30,19:00',
    description:
        'Local start times, comma-separated HH:mm. Must be at least one slot '
        'length apart, or one person could be available for two at once.',
  );

  /// How long a slot runs.
  static final ConfigKey<Duration> slotDuration = ConfigKey.duration(
    'schedule.slot_duration',
    defaultValue: const Duration(minutes: 90),
    description:
        'How long a slot runs. Ninety minutes is long enough to be an evening '
        'and short enough that leaving is not a decision.',
  );

  /// How far ahead slots are materialised.
  static final ConfigKey<int> horizonWeeks = ConfigKey.integer(
    'schedule.horizon_weeks',
    defaultValue: 2,
    description:
        'How many weeks of slots exist ahead of now. Too short and nobody can '
        'plan; too long and a schedule change has to unpick slots people have '
        'already answered.',
  );

  /// Every key, for the console editor.
  static final List<ConfigKey<Object?>> all = [
    weekdays,
    startTimes,
    slotDuration,
    horizonWeeks,
  ];

  /// The console group, with the rules that hold between these keys.
  static final ConfigGroup group = ConfigGroup(
    name: 'Schedule',
    description: 'Which evenings a city runs, and when its slots start.',
    keys: all,
    invariants: [
      ConfigInvariant(
        name: 'the schedule is materialisable',
        explanation:
            'The weekday and start-time lists must parse, and no two slots on '
            'a day may overlap. An unparseable schedule generates no slots at '
            'all, which looks exactly like a quiet week.',
        holds: (snapshot) => SlotSchedule.fromSnapshot(snapshot).isOk,
      ),
      ConfigInvariant(
        name: 'the horizon reaches at least one week',
        explanation:
            'With a horizon below one week, a person setting availability on '
            'Sunday sees nothing to set it for.',
        holds: (snapshot) => snapshot.get(horizonWeeks) >= 1,
      ),
    ],
  );
}
