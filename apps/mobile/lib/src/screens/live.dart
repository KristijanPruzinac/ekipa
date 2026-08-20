import 'dart:math' as math;

import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:mobile/src/widgets/async_block.dart';

/// The hangout, while it is happening.
///
/// Two screens in one, because they are the same fifteen minutes: **arrival**,
/// until everybody has tapped, and then **the activity**.
///
/// **Arrival is peer-attested, not self-declared** (`02_DOMAIN.md §4`). Each
/// member taps for themselves *and* can say whether somebody else is there. A
/// no-show can tap "arrived" from home and the system cannot tell — and
/// attendance drives edges, trust and sanctions, so a purely self-reported
/// input to a sanction system is an open invitation.
///
/// **Every phone taps.** The transcript is explicit that this is a duty and
/// that one tap per group is not enough. So the attestation control appears on
/// every member's screen, for every other member, and the copy says why.
class LiveScreen extends ConsumerWidget {
  /// The live view of [hangout].
  const LiveScreen({required this.hangout, super.key});

  /// What is happening.
  final Hangout hangout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final everybodyHere =
        hangout.members.isNotEmpty &&
        hangout.members.every((member) => member.arrived);
    return everybodyHere
        ? _Activity(hangout: hangout)
        : _Arrival(hangout: hangout);
  }
}

/// Waiting for the group to assemble.
class _Arrival extends ConsumerWidget {
  const _Arrival({required this.hangout});

  final Hangout hangout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).nowUtc();
    final since = now.difference(hangout.startsAt);
    final graceOver = since > const Duration(minutes: 15);
    final missing = hangout.members.where((member) => !member.arrived).toList();

    return EkipaScreen(
      title: hangout.youArrived ? 'Waiting for the others' : 'Are you there?',
      lede: hangout.youArrived
          ? 'The deck unlocks when everybody has tapped. That is the point — '
                'it is the group’s first thing done together.'
          : 'Tap when you can actually see the meeting point. Everyone taps '
                'for themselves.',
      action: hangout.youArrived ? null : _ArrivedButton(hangoutId: hangout.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hangout.sigil != null)
            Center(
              child: Sigil(
                symbol: hangout.sigil!.symbol,
                colour: hangout.sigil!.colour,
                size: 56,
                label: hangout.sigil!.label,
              ),
            ),
          const SizedBox(height: ZarSpace.xl),

          for (final member in hangout.members) ...[
            _PresenceRow(
              hangout: hangout,
              member: member,
              canAttest: graceOver && !member.isYou && hangout.youArrived,
            ),
            const SizedBox(height: ZarSpace.xs),
          ],

          if (graceOver && missing.isNotEmpty) ...[
            const SizedBox(height: ZarSpace.lg),
            EkipaCard(
              tone: EkipaCardTone.live,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fifteen minutes have passed',
                    style: ZarType.bodyStrong.copyWith(color: ZarColors.amber),
                  ),
                  const SizedBox(height: ZarSpace.xs),
                  Text(
                    'If somebody is not here, say so on your own phone. Every '
                    'person marks it themselves — one person saying it is not '
                    'enough, and that is deliberate: it means two people who '
                    'know each other cannot decide somebody was absent.\n\n'
                    'You have until half an hour past the start.',
                    style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: ZarSpace.xl),
          if (!graceOver)
            Text(
              'Give it fifteen minutes before marking anybody absent. People '
              'are late for ordinary reasons.',
              style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
            ),
        ],
      ),
    );
  }
}

class _PresenceRow extends ConsumerWidget {
  const _PresenceRow({
    required this.hangout,
    required this.member,
    required this.canAttest,
  });

  final Hangout hangout;
  final Member member;
  final bool canAttest;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EkipaCard(
    padding: const EdgeInsets.symmetric(
      horizontal: ZarSpace.md,
      vertical: ZarSpace.sm,
    ),
    child: Row(
      children: [
        Expanded(child: PersonName(member.name)),
        if (member.arrived)
          const ZarChip('here', tone: ZarChipTone.good, dot: true)
        else if (canAttest)
          EkipaButton(
            label: 'Not here',
            tone: EkipaButtonTone.quiet,
            onPressed: () => ref
                .read(gatewayProvider)
                .attest(
                  hangoutId: hangout.id,
                  memberId: member.id,
                  present: false,
                ),
          )
        else
          const ZarChip('not yet', tone: ZarChipTone.waiting, dot: true),
      ],
    ),
  );
}

class _ArrivedButton extends ConsumerStatefulWidget {
  const _ArrivedButton({required this.hangoutId});

  final String hangoutId;

  @override
  ConsumerState<_ArrivedButton> createState() => _ArrivedButtonState();
}

class _ArrivedButtonState extends ConsumerState<_ArrivedButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => EkipaButton(
    label: 'I’m here',
    busy: _busy,
    onPressed: _busy
        ? null
        : () async {
            setState(() => _busy = true);
            try {
              await ref.read(gatewayProvider).markArrived(widget.hangoutId);
              ref.invalidate(hangoutsProvider);
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
  );
}

/// The activity, one card at a time.
class _Activity extends ConsumerStatefulWidget {
  const _Activity({required this.hangout});

  final Hangout hangout;

  @override
  ConsumerState<_Activity> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<_Activity> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(activityCardsProvider(widget.hangout.id));
    return EkipaScreen(
      leading: Text(
        widget.hangout.activity.name.toUpperCase(),
        style: ZarType.monoKey.copyWith(
          color: ZarColors.ember,
          letterSpacing: 1.2,
        ),
      ),
      // The one decision goes in the shell's pinned slot like every other
      // screen's. It used to sit inline, a third of the way down a page whose
      // remaining two thirds were empty — which is what a phone screen looks
      // like when a column of short text is asked to fill it.
      action: _next(cards),
      child: AsyncBlock<List<ActivityCard>>(
        value: cards,
        builder: (loaded) {
          if (loaded.isEmpty) return const SizedBox.shrink();
          final card = loaded[_index.clamp(0, loaded.length - 1)];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Progress(index: card.index, total: card.total),
              const SizedBox(height: ZarSpace.xl),
              // **It is a card, so it is drawn as one.** Four people are
              // looking at one phone held between them; the question needs to
              // be the object on the screen, not a paragraph at the top of it.
              EkipaCard(
                padding: const EdgeInsets.all(ZarSpace.xl),
                child: ConstrainedBox(
                  // Sized from the viewport rather than from the text, so the
                  // card is the screen and not a paragraph with a lot of room
                  // under it. The subtraction is the chrome around it — the
                  // activity label, the progress bar, the pass note and the
                  // pinned button — and the floor keeps a very short phone
                  // from collapsing it to nothing. A card that changed height
                  // with the question would make the deck feel unsteady as it
                  // advanced, which is the opposite of what a shared object in
                  // the middle of a table should do.
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      240,
                      MediaQuery.sizeOf(context).height - 340,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(card.text, style: ZarType.title),
                      const SizedBox(height: ZarSpace.md),
                      Text(
                        card.note,
                        style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZarSpace.md),
              // Pass is always available, on every card, for every person, with
              // no explanation and no visible record. A question deck without a
              // free pass is an interrogation.
              Center(
                child: Text(
                  'Anyone can pass on any card. Say “pass” and it moves on — '
                  'nothing is recorded.',
                  textAlign: TextAlign.center,
                  style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The pinned button, which has to be built outside [AsyncBlock] because the
  /// shell's action slot is a sibling of the body, not a child of it.
  Widget? _next(AsyncValue<List<ActivityCard>> cards) {
    final loaded = cards.value;
    if (loaded == null || loaded.isEmpty) return null;
    final card = loaded[_index.clamp(0, loaded.length - 1)];
    final last = card.index == card.total - 1;
    return EkipaButton(
      label: last ? 'That is the deck' : 'Next',
      onPressed: last ? null : () => setState(() => _index = card.index + 1),
    );
  }
}

/// How far through the deck the group is.
///
/// A bar rather than "4 / 12": the useful question during a conversation is
/// "are we near the end", not "which number is this", and a countdown of cards
/// turns a conversation into a task.
class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: i <= index ? ZarColors.ember : ZarColors.hairline,
              borderRadius: ZarRadius.allPill,
            ),
          ),
        ),
      ],
    ],
  );
}
