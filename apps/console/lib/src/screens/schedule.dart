import 'package:console/src/data/records.dart';
import 'package:console/src/state/providers.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:console/src/widgets/console_chrome.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The city's week.
///
/// **Intention — the screen shows the rule and the rows it produced, side by
/// side.** A schedule is four config keys; the slots are what those keys became
/// on a calendar. Showing only the keys hides whether anybody ran the
/// generator; showing only the slots hides why they are what they are. The
/// signature column joins them: every row says which schedule made it, so a
/// slot generated under last month's rule is visibly different from one
/// generated under this month's.
///
/// **The division of labour, restated where it is easiest to break.** The dates
/// come from `SlotSchedule.materialise` in `ekipa_core` — pure calendar
/// arithmetic, no zone. Turning `2026-10-25 17:30 Europe/Zagreb` into an
/// instant happens in Postgres, because that is where the tz database lives.
/// Nothing in this file converts a local time to UTC, and nothing in it should
/// ever learn how.
class ScheduleScreen extends ConsumerWidget {
  /// Creates the screen.
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(ZarSpace.xl),
    children: [
      AsyncBlock<List<CityRecord>>(
        value: ref.watch(citiesProvider),
        builder: _CityBar.new,
      ),
      const SizedBox(height: ConsoleSpace.blockGap),
      ConsoleSection(
        title: 'The rule',
        lede: 'Four configuration keys. Change them under Configuration.',
        child: AsyncBlock<Result<SlotSchedule, String>?>(
          value: ref.watch(scheduleProvider),
          builder: _ScheduleCard.new,
        ),
      ),
      const SizedBox(height: ConsoleSpace.sectionGap),
      const _SlotSection(),
      const SizedBox(height: ConsoleSpace.sectionGap),
    ],
  );
}

class _CityBar extends ConsumerWidget {
  const _CityBar(this.cities);

  final List<CityRecord> cities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cities.isEmpty) {
      return const _Hollow(
        'No city exists yet. Slots cannot be generated until one does.',
      );
    }
    final active = ref.watch(activeCityProvider).value;
    return EkipaCard(
      child: Row(
        children: [
          DropdownButton<String>(
            value: active?.id.value,
            dropdownColor: ZarColors.surfaceRaised,
            underline: const SizedBox.shrink(),
            style: ConsoleType.value,
            items: [
              for (final city in cities)
                DropdownMenuItem<String>(
                  value: city.id.value,
                  child: Text(city.name, style: ConsoleType.value),
                ),
            ],
            onChanged: (chosen) =>
                ref.read(selectedCityProvider.notifier).selected =
                    chosen == null ? null : CityId(chosen),
          ),
          const SizedBox(width: ZarSpace.md),
          if (active != null) ...[
            // The zone is on screen because it is the input to the one
            // conversion that can silently be an hour wrong.
            Text(active.timezone, style: ConsoleType.chip),
            const SizedBox(width: ZarSpace.md),
            Text(
              '${active.slotCount} slots ahead',
              style: ConsoleType.chip,
            ),
            const SizedBox(width: ZarSpace.md),
            if (!active.active)
              Text(
                'INACTIVE',
                style: ConsoleType.chip.copyWith(color: ZarColors.amber),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(this.result);

  final Result<SlotSchedule, String>? result;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final outcome = result;
    if (outcome == null) {
      return const _Hollow('No configuration version to read a schedule from.');
    }
    final schedule = outcome.valueOrNull;
    if (schedule == null) {
      // `SlotSchedule.parse` explains itself — "start times 16:00 and 17:00
      // overlap: they are 60 minutes apart and a slot is 90 minutes long". The
      // console prints that and adds nothing.
      return ProblemPanel([
        ConfigProblem(
          code: ConfigProblemCode.unparseableValue,
          detail: outcome.errorOrNull!,
        ),
      ]);
    }
    return EkipaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactStrip([
            Fact(
              'Evenings',
              schedule.weekdays.map((day) => _days[day - 1]).join(' · '),
            ),
            Fact(
              'Starts',
              schedule.startTimes.map((time) => '$time').join(' · '),
            ),
            Fact('Length', '${schedule.duration.inMinutes} min'),
          ]),
          const SizedBox(height: ZarSpace.md),
          Row(
            children: [
              Text(
                '${schedule.slotsPerWeek} slots a week',
                style: ZarType.body,
              ),
              const SizedBox(width: ZarSpace.md),
              Flexible(
                child: Text(schedule.signature, style: ConsoleType.chip),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rows the rule produced, and the button that produces more.
class _SlotSection extends ConsumerStatefulWidget {
  const _SlotSection();

  @override
  ConsumerState<_SlotSection> createState() => _SlotSectionState();
}

class _SlotSectionState extends ConsumerState<_SlotSection> {
  final TextEditingController _reason = TextEditingController();
  String? _outcome;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _generate(CityRecord city, SlotSchedule schedule) async {
    setState(() {
      _busy = true;
      _outcome = null;
    });
    try {
      final now = ref.read(clockProvider).nowUtc();
      final resolved = await ref.read(resolvedConfigProvider.future);
      final weeks = resolved == null
          ? ScheduleKeys.horizonWeeks.defaultValue
          : resolved.snapshot.get(ScheduleKeys.horizonWeeks);
      final made = await ref
          .read(gatewayProvider)
          .generateSlots(
            cityId: city.id,
            slots: schedule.materialise(from: now, weeks: weeks),
            generatedBy: schedule.signature,
            reason: _reason.text.trim(),
          );
      // A count, in the console's own words, because this one is genuinely the
      // console's own fact: the server returned a number and nothing else.
      setState(() => _outcome = '$made new slots.');
      ref
        ..invalidate(slotsProvider)
        ..invalidate(citiesProvider)
        ..invalidate(auditProvider);
    } on Object catch (error) {
      setState(() => _outcome = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(activeCityProvider).value;
    final schedule = ref.watch(scheduleProvider).value?.valueOrNull;
    final role = ref.watch(roleProvider).value;
    final canGenerate =
        city != null &&
        schedule != null &&
        !_busy &&
        _reason.text.trim().isNotEmpty &&
        atLeast(role, 'operator');

    return ConsoleSection(
      title: 'The week',
      lede: 'Generating twice adds nothing — the second run is idempotent.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AsyncBlock<List<SlotRecord>>(
            value: ref.watch(slotsProvider),
            builder: (slots) => ConsoleTable(
              columns: const [
                (label: 'Date', flex: 3, numeric: false),
                (label: 'Local', flex: 2, numeric: true),
                (label: 'UTC', flex: 2, numeric: true),
                (label: 'Free', flex: 2, numeric: true),
                (label: 'Generated by', flex: 4, numeric: false),
              ],
              rows: [
                for (final slot in slots)
                  [
                    Text(slot.localDate, style: ConsoleType.value),
                    Text(slot.localTime, style: ConsoleType.value),
                    // Both clocks, side by side. This column is the only place
                    // the daylight-saving boundary is visible to a human: the
                    // same 17:30 reads 15:30 in October and 16:30 a week later.
                    Text(_utcClock(slot.startsAt), style: ConsoleType.value),
                    Text('${slot.available}', style: ConsoleType.value),
                    Text(
                      slot.generatedBy ?? '—',
                      style: ConsoleType.chip,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: ZarSpace.lg),
          const Text(
            'WHY YOU ARE GENERATING',
            style: ConsoleType.columnHead,
          ),
          const SizedBox(height: ZarSpace.xs),
          TextField(
            controller: _reason,
            style: ZarType.body,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(ZarSpace.sm),
              enabledBorder: OutlineInputBorder(
                borderRadius: ZarRadius.allSm,
                borderSide: BorderSide(color: ZarColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ZarRadius.allSm,
                borderSide: BorderSide(color: ZarColors.focus),
              ),
            ),
          ),
          if (_outcome case final String line) ...[
            const SizedBox(height: ZarSpace.md),
            Verbatim(line),
          ],
          const SizedBox(height: ZarSpace.lg),
          ConsoleAction(
            label: _busy ? 'Generating…' : 'Generate the horizon',
            onPressed: canGenerate ? () => _generate(city, schedule) : null,
          ),
        ],
      ),
    );
  }
}

String _utcClock(DateTime instant) {
  final utc = instant.toUtc();
  return '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}Z';
}

class _Hollow extends StatelessWidget {
  const _Hollow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ZarSpace.lg),
    decoration: BoxDecoration(
      borderRadius: ZarRadius.allMd,
      border: Border.all(color: ZarColors.hairline),
    ),
    child: Text(text, style: ConsoleType.note),
  );
}
