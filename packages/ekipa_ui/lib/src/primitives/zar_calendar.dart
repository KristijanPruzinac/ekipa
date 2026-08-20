import 'package:ekipa_ui/src/primitives/pressable.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// One day in a [ZarCalendar].
@immutable
final class CalendarDay {
  /// Describes a day the calendar can draw.
  const CalendarDay({
    required this.date,
    this.slots = 0,
    this.chosen = 0,
    this.density = 0,
    this.past = false,
  });

  /// Local calendar date. Time is ignored.
  final DateTime date;

  /// How many slots this day offers. Zero means the city does not run.
  final int slots;

  /// How many of them the person has said yes to.
  final int chosen;

  /// How likely a hangout is at this time, `0…1`.
  ///
  /// **The transcript asked for exactly this** — *"an indicator background
  /// behind slot that indicates its a good time to pick as you are likely to
  /// find a hang out"* — and `05_PLACES.md §7` says how it must be computed: a
  /// coarse bucket over an H3 hex, never a raw count. A raw count is gameable
  /// and it publishes how thin the network is, which is the one number a young
  /// network cannot afford to show.
  final double density;

  /// Whether the day has gone by. Drawn, not hidden: a month with holes in it
  /// is harder to read than a month with quiet days in it.
  final bool past;

  /// Whether this day can be opened.
  bool get selectable => slots > 0 && !past;
}

/// A month, with the operating days live.
///
/// **Intention — a person thinks in evenings, and evenings live on a
/// calendar.** The first build of this screen was a scrolling list of day cards
/// with time chips inside them. It was a form. You could not see a week at
/// once, "am I around next Thursday" took a scroll, and there was nowhere to
/// put the density indicator the transcript asked for. A month grid answers all
/// three in one surface: the shape of the month is the shape of the month.
///
/// **What is deliberately absent:** every day of the week. Osijek runs
/// Thursday, Friday and Saturday, so four cells in five are dead. Drawing them
/// anyway — dimmed, unlabelled, unpressable — is what makes the three live ones
/// legible at a glance. Compressing the grid to three columns would save space
/// and destroy the one thing a calendar is for, which is knowing what day it
/// is.
class ZarCalendar extends StatelessWidget {
  /// Draws [month] with [days] filled in.
  const ZarCalendar({
    required this.month,
    required this.days,
    required this.onDayPressed,
    this.selected,
    this.weekdayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    super.key,
  });

  /// Any date inside the month to draw.
  final DateTime month;

  /// The days the caller knows about, keyed by date. Days not listed are drawn
  /// as quiet cells.
  final List<CalendarDay> days;

  /// Called when a live day is tapped.
  final void Function(CalendarDay day) onDayPressed;

  /// The day currently open, if any.
  final DateTime? selected;

  /// Monday-first initials.
  final List<String> weekdayLabels;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // ISO weekday: Monday is 1. The grid starts on Monday because Croatia does.
    final leading = first.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _Cell(
          day:
              days.cast<CalendarDay?>().firstWhere(
                (candidate) =>
                    candidate != null &&
                    _sameDay(
                      candidate.date,
                      DateTime(month.year, month.month, day),
                    ),
                orElse: () => null,
              ) ??
              CalendarDay(
                date: DateTime(month.year, month.month, day),
                past: DateTime(month.year, month.month, day).isBefore(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              ),
          open:
              selected != null &&
              _sameDay(selected!, DateTime(month.year, month.month, day)),
          onPressed: onDayPressed,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_monthNames[month.month - 1]} ${month.year}',
          style: ZarType.bodyStrong,
        ),
        const SizedBox(height: ZarSpace.md),
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: ZarSpace.xs),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ZarSpace.xxs,
          crossAxisSpacing: ZarSpace.xxs,
          children: cells,
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.open, required this.onPressed});

  final CalendarDay day;
  final bool open;
  final void Function(CalendarDay day) onPressed;

  @override
  Widget build(BuildContext context) {
    final live = day.selectable;
    final picked = day.chosen > 0;

    // The density wash sits *behind* the number, never on it: the indicator is
    // a hint about supply, and a hint that makes the date harder to read has
    // cost more than it gave.
    final wash = live && day.density > 0
        ? ZarColors.ember.withValues(
            alpha: 0.06 + 0.16 * day.density.clamp(0, 1),
          )
        : null;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: picked
            ? ZarColors.ember
            : wash ?? (live ? ZarColors.surface : null),
        borderRadius: ZarRadius.allSm,
        border: open && !picked
            ? Border.all(color: ZarColors.ember, width: 1.5)
            : live && !picked
            ? Border.all(color: ZarColors.hairline)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.date.day}',
              style: ZarType.label.copyWith(
                color: picked
                    ? ZarColors.emberInk
                    : live
                    ? ZarColors.ink
                    : ZarColors.inkFaint.withValues(
                        alpha: day.past ? 0.35 : 0.55,
                      ),
                fontWeight: live ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (live)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _Pips(
                  total: day.slots,
                  filled: day.chosen,
                  onEmber: picked,
                ),
              ),
          ],
        ),
      ),
    );

    if (!live) {
      return Semantics(
        label: '${day.date.day}, no hangouts',
        excludeSemantics: true,
        child: content,
      );
    }
    return Pressable(
      onPressed: () => onPressed(day),
      semanticLabel: day.chosen > 0
          ? '${day.date.day}, ${day.chosen} of ${day.slots} times chosen'
          : '${day.date.day}, ${day.slots} times free',
      child: content,
    );
  }
}

/// One dot per slot, filled for the ones taken.
///
/// Three dots read faster than "1/3" and take a quarter of the width, which
/// matters in a cell this size. They also carry the shape of the evening: a day
/// with one slot left looks different from a day with three.
class _Pips extends StatelessWidget {
  const _Pips({
    required this.total,
    required this.filled,
    required this.onEmber,
  });

  final int total;
  final int filled;
  final bool onEmber;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled
                ? (onEmber ? ZarColors.emberInk : ZarColors.ember)
                : (onEmber
                      ? ZarColors.emberInk.withValues(alpha: 0.3)
                      : ZarColors.inkFaint.withValues(alpha: 0.45)),
          ),
        ),
    ],
  );
}
