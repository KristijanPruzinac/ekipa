import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:mobile/src/widgets/async_block.dart';

/// Which evenings you are around.
///
/// **Intention — a calendar, because a person thinks in evenings and evenings
/// live on a calendar.** The first version of this screen was a scrolling list
/// of day cards with time chips inside them. It was a form: you could not see a
/// week at once, "am I around next Thursday" took a scroll, and there was
/// nowhere to put the density indicator the transcript asked for. This is a
/// month grid where the three operating days are the live cells; tapping one
/// opens its three times underneath.
///
/// **Nothing is written per tap.** Taps accumulate in [availabilityProvider]
/// and one button sends the whole set — see that class for why a delta is the
/// wrong shape. The button is pinned above the safe area and never scrolls
/// away, because a person who has tapped nine slots must not have to find the
/// save.
class AvailabilityScreen extends ConsumerStatefulWidget {
  /// The picker.
  const AvailabilityScreen({this.onDone, super.key});

  /// Where to go when it is saved. `null` stays put.
  final VoidCallback? onDone;

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  @override
  void initState() {
    super.initState();

    // Seeding the draft from the server's answer takes **two** hooks, and
    // leaving either one out is a real bug rather than belt-and-braces.
    //
    // The subscription covers the ordinary mount, where the slots are still
    // loading and data arrives a moment later. The post-frame read covers the
    // mount where they are *already* loaded — arriving here from the home
    // screen, which has watched the same provider — because a listener only
    // fires on a change and there is no change left to fire.
    //
    // Neither can run inside `initState` or `build` directly: writing to a
    // provider while the tree is building throws. `startFrom` is idempotent,
    // so the two hooks overlapping costs nothing.
    ref.listenManual<AsyncValue<List<SlotDay>>>(slotDaysProvider, (_, next) {
      _seed(next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _seed(ref.read(slotDaysProvider));
    });
  }

  void _seed(AsyncValue<List<SlotDay>> days) {
    if (days case AsyncData(:final value)) {
      ref
          .read(availabilityProvider.notifier)
          .startFrom(value.expand((day) => day.slots));
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(slotCalendarProvider);
    final draft = ref.watch(availabilityProvider);
    final open = ref.watch(openDayProvider);

    return EkipaScreen(
      title: 'Which evenings are you around?',
      lede:
          'Say yes to anything that could work. You are not committing to '
          'anything yet — the morning of, we ask again.',
      action: draft == null || draft.isEmpty
          ? const EkipaButton(
              label: 'Pick at least one evening',
              onPressed: null,
            )
          : _SaveButton(draft: draft, onDone: widget.onDone),
      secondaryAction: _RepeatButton(onDone: widget.onDone),
      child: AsyncBlock<List<SlotDay>>(
        value: days,
        empty: 'The schedule for the next few weeks is not out yet.',
        builder: (loaded) {
          if (loaded.isEmpty) return const _NoSlots();
          final months = _months(loaded);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final month in months) ...[
                ZarCalendar(
                  month: month,
                  selected: open,
                  days: [
                    for (final day in loaded)
                      if (day.day.year == month.year &&
                          day.day.month == month.month)
                        CalendarDay(
                          date: day.day,
                          slots: day.slots.length,
                          chosen: day.chosenCount,
                          density: day.density,
                        ),
                  ],
                  onDayPressed: (day) =>
                      ref.read(openDayProvider.notifier).toggle(day.date),
                ),
                if (open != null &&
                    open.year == month.year &&
                    open.month == month.month) ...[
                  const SizedBox(height: ZarSpace.lg),
                  _Times(
                    day: loaded.firstWhere(
                      (candidate) => candidate.day == open,
                    ),
                  ),
                ],
                const SizedBox(height: ZarSpace.xl),
              ],
              const _Legend(),
            ],
          );
        },
      ),
    );
  }

  List<DateTime> _months(List<SlotDay> days) {
    final seen = <String, DateTime>{};
    for (final day in days) {
      seen['${day.day.year}-${day.day.month}'] ??= DateTime(
        day.day.year,
        day.day.month,
      );
    }
    return seen.values.toList()..sort((a, b) => a.compareTo(b));
  }
}

/// The three times on the open day.
class _Times extends ConsumerWidget {
  const _Times({required this.day});

  final SlotDay day;

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(availabilityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_weekdays[day.weekday - 1]} ${day.day.day}',
          style: ZarType.bodyStrong,
        ),
        const SizedBox(height: ZarSpace.xs),
        Text(
          'Each one runs an hour and a half.',
          style: ZarType.caption.copyWith(color: ZarColors.inkMuted),
        ),
        const SizedBox(height: ZarSpace.sm),
        Row(
          children: [
            for (final (index, slot) in day.slots.indexed) ...[
              if (index > 0) const SizedBox(width: ZarSpace.xs),
              Expanded(
                child: ZarTimeChip(
                  time: slot.localTime,
                  note: _likelihood(slot.density),
                  density: slot.density,
                  selected: draft?.contains(slot.id) ?? slot.chosen,
                  onPressed: () =>
                      ref.read(availabilityProvider.notifier).toggle(slot.id),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// A coarse bucket, in one word.
  ///
  /// **Never a count.** `05_PLACES.md §7`: a raw number is gameable and it
  /// publishes how thin the network is, which is the one figure a young network
  /// cannot afford to show. One word carries everything the decision needs.
  ///
  /// One word rather than two, because these sit under a time in a chip a third
  /// of the screen wide: "usually busy" wrapped, and a wrapped note in one of
  /// three side-by-side chips made the row look broken.
  String _likelihood(double density) => switch (density) {
    >= 0.8 => 'busiest',
    >= 0.55 => 'busy',
    >= 0.35 => 'quieter',
    _ => 'quiet',
  };
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: ZarColors.ember.withValues(alpha: 0.2),
          borderRadius: ZarRadius.allSm,
        ),
      ),
      const SizedBox(width: ZarSpace.xs),
      Expanded(
        child: Text(
          'A warmer day is one where more people are around, so a hangout is '
          'likelier to form.',
          style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
        ),
      ),
    ],
  );
}

class _SaveButton extends ConsumerStatefulWidget {
  const _SaveButton({required this.draft, required this.onDone});

  final Set<SlotId> draft;
  final VoidCallback? onDone;

  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton> {
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(gatewayProvider).setAvailability(widget.draft);
      ref.invalidate(slotsProvider);
      widget.onDone?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.draft.length;
    return EkipaButton(
      label: count == 1 ? 'Save one evening' : 'Save $count times',
      busy: _busy,
      onPressed: _busy ? null : _save,
    );
  }
}

class _RepeatButton extends ConsumerWidget {
  const _RepeatButton({required this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EkipaButton(
    label: 'Same as last week',
    tone: EkipaButtonTone.quiet,
    onPressed: () async {
      await ref.read(gatewayProvider).repeatLastWeek();
      ref
        ..invalidate(slotsProvider)
        ..read(availabilityProvider.notifier).clear();
    },
  );
}

class _NoSlots extends StatelessWidget {
  const _NoSlots();

  @override
  Widget build(BuildContext context) => EkipaCard(
    tone: EkipaCardTone.quiet,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nothing to pick yet', style: ZarType.bodyStrong),
        const SizedBox(height: ZarSpace.xs),
        Text(
          'The evenings for the next few weeks have not been opened. This is '
          'ours to fix, not yours — check back tomorrow.',
          style: ZarType.body.copyWith(color: ZarColors.inkMuted),
        ),
      ],
    ),
  );
}
