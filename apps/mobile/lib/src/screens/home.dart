import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/state/providers.dart';

/// What is next, and nothing else.
///
/// **Intention — one instruction, not a feed.** The reference set is unanimous
/// that none of these apps shows a dashboard on first run, and this product has
/// less to show than any of them: there is no feed, no browse, no profiles, no
/// discovery. On most days the honest answer is *"nothing yet — here are the
/// evenings you said yes to"*, and a screen that pads that out with cards is a
/// screen pretending to be busier than the product is.
///
/// **The two tabs are the transcript's**: *"Make dating a separate tab up top
/// to the normal meet tab."* Dating is shown locked rather than hidden, so the
/// unlock is something you can see coming.
///
/// **No numbers about people.** No streak, no score, no badge — Opal's gauge is
/// excellent for sleep and would be poison here (`docs/reference/README.md`).
/// The one count that appears is how many hangouts you have been to, and only
/// because it is what the dating tab is waiting for.
class HomeScreen extends ConsumerStatefulWidget {
  /// The home screen.
  const HomeScreen({
    this.onEditAvailability,
    this.onOpenHangout,
    super.key,
  });

  /// Opens the availability picker.
  final VoidCallback? onEditAvailability;

  /// Opens whatever the next hangout needs.
  final void Function(Hangout hangout)? onOpenHangout;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  String? _lockedNote;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final next = ref.watch(nextHangoutProvider).value;
    final slots = ref.watch(slotsProvider).value ?? const <SlotOption>[];
    final chosen = slots.where((slot) => slot.chosen).length;

    return EkipaScreen(
      leading: profile == null
          ? null
          : Row(
              children: [
                Expanded(child: PersonName(profile.name, hero: true)),
              ],
            ),
      action: next == null
          ? EkipaButton(
              label: chosen == 0
                  ? 'Pick your evenings'
                  : 'Change your evenings',
              onPressed: widget.onEditAvailability,
            )
          : EkipaButton(
              label: _callToAction(next),
              onPressed: widget.onOpenHangout == null
                  ? null
                  : () => widget.onOpenHangout!(next),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedTabs(
            index: _tab,
            segments: [
              const Segment(label: 'Hangouts'),
              Segment(
                label: 'Dating',
                locked: !(profile?.datingUnlocked ?? false),
                lockedNote: profile == null
                    ? null
                    : 'Dating opens after a few hangouts. You have been to '
                          '${profile.completedHangouts}.',
              ),
            ],
            onChanged: (index) => setState(() {
              _tab = index;
              _lockedNote = null;
            }),
            onLockedPressed: (segment) =>
                setState(() => _lockedNote = segment.lockedNote),
          ),
          if (_lockedNote != null) ...[
            const SizedBox(height: ZarSpace.sm),
            Text(
              _lockedNote!,
              style: ZarType.caption.copyWith(color: ZarColors.inkMuted),
            ),
          ],
          const SizedBox(height: ZarSpace.xl),

          if (next != null)
            _NextCard(hangout: next)
          else
            _Quiet(chosen: chosen),

          const SizedBox(height: ZarSpace.xl),
          if (chosen > 0) _YourWeek(slots: slots),
        ],
      ),
    );
  }

  String _callToAction(Hangout hangout) => switch (hangout.phase) {
    HangoutPhase.confirming || HangoutPhase.backfilling => 'Answer',
    HangoutPhase.revealed => 'Open it',
    HangoutPhase.live => 'I’m here',
    HangoutPhase.rating => 'Rate it',
    _ => 'Have a look',
  };
}

/// The one thing that matters, if there is one.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.hangout});

  final Hangout hangout;

  @override
  Widget build(BuildContext context) {
    final (headline, tone, note) = switch (hangout.phase) {
      HangoutPhase.proposed => (
        'You have a hangout',
        ZarChipTone.plain,
        'We will ask you to confirm on the morning. Nothing to do until then.',
      ),
      HangoutPhase.confirming => (
        'Are you coming?',
        ZarChipTone.live,
        'Answer while there is still time to repair the group if you cannot.',
      ),
      HangoutPhase.backfilling => (
        'Finding one more person',
        ZarChipTone.waiting,
        'Somebody could not make it. We are looking, and you will know either '
            'way before you would leave home.',
      ),
      HangoutPhase.locked => (
        'It is on',
        ZarChipTone.good,
        'The place comes out an hour before, with everyone’s names.',
      ),
      HangoutPhase.revealed => (
        'Tonight',
        ZarChipTone.live,
        'You have the place and the mark. Go.',
      ),
      HangoutPhase.live => (
        'Happening now',
        ZarChipTone.live,
        'Tap when you are there.',
      ),
      HangoutPhase.rating => (
        'Rate it',
        ZarChipTone.waiting,
        'Until you do, you will not be put in another one. It takes a minute.',
      ),
      HangoutPhase.cancelled => (
        'Cancelled',
        ZarChipTone.wrong,
        hangout.cancelledBecause ??
            'It could not go ahead. You are first in line for the next run.',
      ),
      HangoutPhase.closed => ('Done', ZarChipTone.plain, 'That is that one.'),
    };

    return EkipaCard(
      tone: tone == ZarChipTone.live ? EkipaCardTone.live : EkipaCardTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(headline, style: ZarType.heading)),
              if (hangout.sigil != null)
                Sigil(
                  symbol: hangout.sigil!.symbol,
                  colour: hangout.sigil!.colour,
                  size: 34,
                ),
            ],
          ),
          const SizedBox(height: ZarSpace.sm),
          FactStrip([
            Fact('WHEN', hangout.localTime),
            Fact('DAY', hangout.localDay.split(' ').first),
            Fact('WHO', '${hangout.memberCount}'),
          ]),
          const SizedBox(height: ZarSpace.md),
          Text(note, style: ZarType.body.copyWith(color: ZarColors.inkMuted)),
          if (hangout.meetingPoint != null) ...[
            const SizedBox(height: ZarSpace.md),
            VenueName(hangout.meetingPoint!.name),
          ],
        ],
      ),
    );
  }
}

/// The honest answer on most days.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.chosen});

  final int chosen;

  @override
  Widget build(BuildContext context) => EkipaCard(
    tone: EkipaCardTone.quiet,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chosen == 0 ? 'Nothing yet' : 'Nothing yet — you are in the pool',
          style: ZarType.heading,
        ),
        const SizedBox(height: ZarSpace.xs),
        Text(
          chosen == 0
              ? 'Say which evenings you are around and the matching will do '
                    'the rest. It runs once a day.'
              : 'The matching runs once a day and forms groups a couple of '
                    'days ahead. If one comes together with you in it, this is '
                    'where you will hear about it.',
          style: ZarType.body.copyWith(color: ZarColors.inkMuted),
        ),
      ],
    ),
  );
}

/// The evenings you said yes to, so the pool is not an abstraction.
class _YourWeek extends StatelessWidget {
  const _YourWeek({required this.slots});

  final List<SlotOption> slots;

  static const List<String> _short = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final taken = slots.where((slot) => slot.chosen).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOU SAID YES TO',
          style: ZarType.label.copyWith(
            color: ZarColors.inkFaint,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: ZarSpace.sm),
        Wrap(
          spacing: ZarSpace.xs,
          runSpacing: ZarSpace.xs,
          children: [
            for (final slot in taken)
              ZarChip(
                '${_short[slot.localWeekday - 1]} ${slot.localTime}',
              ),
          ],
        ),
      ],
    );
  }
}

/// What a suspended person sees.
///
/// **The reason is the server's sentence, printed verbatim.** A sanction the
/// person cannot understand is a sanction they cannot appeal, and an automated
/// decision with a significant effect has to be appealable — both because it is
/// right and because GDPR Art. 22 requires it (`01_ARCHITECTURE.md §11`).
///
/// **What is deliberately not here: the score.** Standing is service-role only
/// (invariant 7). A person sees what they cannot do and until when, never the
/// number that produced it — a visible trust score becomes a status game inside
/// a week.
class SuspendedScreen extends ConsumerWidget {
  /// The suspension notice.
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(sanctionProvider).value;
    return EkipaScreen(
      title: 'You are out for now',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice != null) ...[
            Text(
              'WHY',
              style: ZarType.label.copyWith(
                color: ZarColors.rose,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: ZarSpace.xs),
            Text(notice.reason, style: ZarType.body),
            const SizedBox(height: ZarSpace.xl),
            if (notice.until case final DateTime lifts) ...[
              Text(
                'UNTIL',
                style: ZarType.label.copyWith(
                  color: ZarColors.inkFaint,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: ZarSpace.xs),
              Text(
                '${lifts.day}.${lifts.month}.${lifts.year}.',
                style: ZarType.mono,
              ),
              const SizedBox(height: ZarSpace.xl),
            ],
            if (notice.appealable)
              EkipaCard(
                tone: EkipaCardTone.quiet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('If this is wrong', style: ZarType.bodyStrong),
                    const SizedBox(height: ZarSpace.xs),
                    Text(
                      'This was decided automatically. A person will read '
                      'your appeal and can undo it — that is a right you '
                      'have, not a favour.',
                      style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
