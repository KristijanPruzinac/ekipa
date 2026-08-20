import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:mobile/src/widgets/safety_brief.dart';

/// The morning-of question.
///
/// **Intention — convert silence into information.** The system's scarce
/// resource is time to repair. An early "no" is cooperative: it arrives while
/// it is still actionable, and it costs almost nothing. Silence destroys the
/// repair window and usually becomes a no-show, so it is priced six times
/// higher (`04_TRUST.md §3`).
///
/// **That incentive is stated on the screen, in plain words.** An incentive
/// nobody knows about is not an incentive — it is a trap that people only learn
/// about from the sanction. So "no" is a real, equal-weight button with an
/// honest line under it, not a small grey link beneath a large orange yes.
///
/// **The safety brief runs first** (D12), because this is the moment opting out
/// is still free.
class ConfirmScreen extends ConsumerStatefulWidget {
  /// The confirmation for [hangout].
  const ConfirmScreen({required this.hangout, this.onAnswered, super.key});

  /// What is being confirmed.
  final Hangout hangout;

  /// Called after the answer lands.
  final void Function({required bool coming})? onAnswered;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  bool _briefRead = false;
  bool _busy = false;

  Future<void> _answer({required bool coming}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(gatewayProvider)
          .confirm(hangoutId: widget.hangout.id, coming: coming);
      ref.invalidate(hangoutsProvider);
      widget.onAnswered?.call(coming: coming);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hangout = widget.hangout;
    return EkipaScreen(
      title: 'Tonight?',
      lede:
          '${hangout.localDay} at ${hangout.localTime}, for an hour and a '
          'half. ${hangout.memberCount} people, including you.',
      action: !_briefRead
          ? null
          : EkipaButton(
              label: 'Yes, I am coming',
              busy: _busy,
              onPressed: _busy ? null : () => _answer(coming: true),
            ),
      secondaryAction: !_briefRead
          ? null
          : EkipaButton(
              label: 'No, not tonight',
              tone: EkipaButtonTone.quiet,
              onPressed: _busy ? null : () => _answer(coming: false),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactStrip([
            Fact('WHEN', hangout.localTime),
            Fact('WHO', '${hangout.memberCount} people'),
          ]),
          const SizedBox(height: ZarSpace.lg),

          if (hangout.confirmDeadline != null) _Deadline(hangout: hangout),
          const SizedBox(height: ZarSpace.md),

          // The honest line about declining, on the screen where it applies.
          EkipaCard(
            tone: EkipaCardTone.quiet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saying no is nearly free',
                  style: ZarType.bodyStrong,
                ),
                const SizedBox(height: ZarSpace.xs),
                Text(
                  'If tonight does not work, say so now. It costs you almost '
                  'nothing and it gives us time to find somebody else, so the '
                  'evening still happens for the other three.\n\n'
                  'Not answering at all is the expensive one. By the time '
                  'silence tells us anything, it is too late to fix.',
                  style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZarSpace.xl),

          const Text('What you are saying yes to', style: ZarType.heading),
          const SizedBox(height: ZarSpace.sm),
          EkipaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hangout.activity.name, style: ZarType.bodyStrong),
                const SizedBox(height: ZarSpace.xxs),
                Text(
                  hangout.activity.summary,
                  style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                ),
                if (hangout.activity.equipment != null) ...[
                  const SizedBox(height: ZarSpace.sm),
                  ZarChip(
                    'bring: ${hangout.activity.equipment}',
                    tone: ZarChipTone.live,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZarSpace.xxl),

          if (_briefRead)
            EkipaCard(
              tone: EkipaCardTone.quiet,
              child: Text(
                'Safety brief read. You will see it once more an hour before, '
                'when the place comes out.',
                style: ZarType.body.copyWith(color: ZarColors.mint),
              ),
            )
          else
            SafetyBrief(onRead: () => setState(() => _briefRead = true)),
          const SizedBox(height: ZarSpace.lg),
        ],
      ),
    );
  }
}

/// How long the answer is still worth giving.
class _Deadline extends ConsumerWidget {
  const _Deadline({required this.hangout});

  final Hangout hangout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).nowUtc();
    final left = hangout.confirmDeadline!.difference(now);
    final late = left.isNegative;
    final hours = left.inHours;
    final minutes = left.inMinutes.remainder(60);
    return EkipaCard(
      tone: EkipaCardTone.live,
      child: Row(
        children: [
          Expanded(
            child: Text(
              late
                  ? 'The window has closed. Answer anyway — a late yes still '
                        'helps, and a late no still helps more than nothing.'
                  : 'Answer within ${_remaining(hours, minutes)}, while there '
                        'is still time to repair the group.',
              style: ZarType.body.copyWith(
                color: late ? ZarColors.amber : ZarColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// How long is left, in words a person would say.
  ///
  /// **`1h 0m` is a stopwatch reading, not a sentence.** It appeared in the
  /// first render of this card and it is the kind of thing that makes a screen
  /// feel like a readout of the system's internals rather than something
  /// written for the person in front of it. The zero minutes are dropped
  /// because nobody says them.
  String _remaining(int hours, int minutes) {
    final hourPart = switch (hours) {
      0 => null,
      1 => 'an hour',
      _ => '$hours hours',
    };
    final minutePart = switch (minutes) {
      0 => null,
      1 => 'a minute',
      _ => '$minutes minutes',
    };
    return switch ((hourPart, minutePart)) {
      (final String h, final String m) => '$h and $m',
      (final String h, null) => h,
      (null, final String m) => m,
      _ => 'the next few minutes',
    };
  }
}
