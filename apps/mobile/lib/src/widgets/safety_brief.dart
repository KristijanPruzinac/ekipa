import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';

/// The seven things, shown twice, read past rather than dismissed.
///
/// **Intention — this is the one control in the product that is not
/// statistical.** Everything else in the safety design is a distribution: the
/// respect signal, the report ladder, the composition invariant, the venue
/// visibility rule. They work in aggregate and none of them helps the specific
/// person about to accept a lift home. `00_BIBLE.md` D12 makes this mandatory,
/// unskippable, and shown **twice** — at confirmation, when opting out is still
/// free, and again at reveal, when it is about to matter.
///
/// Its exact words are canon (`00_BIBLE.md` §"The safety brief"); the meaning
/// is fixed even where the wording is not yet final in Croatian.
///
/// **Why the two most specific points are first.** The two most dangerous
/// moments in a stranger meeting are *leaving the public place* and *the
/// journey home*. Everything else here is good advice; those two are the whole
/// control, so they are not buried at position five where a scroll ends.
///
/// **Stating a norm once, at signup, is how norms fail to exist.** That is why
/// this is not a settings page and not an onboarding card.
class SafetyBrief extends StatelessWidget {
  /// The brief, with [onRead] fired once the hold completes.
  const SafetyBrief({
    required this.onRead,
    this.friendHangout = true,
    this.holdLabel = 'I have read this',
    super.key,
  });

  /// Called once, when the hold finishes.
  final VoidCallback onRead;

  /// Whether to include point seven, which is friend-hangout only.
  final bool friendHangout;

  /// What the hold control says.
  final String holdLabel;

  /// The seven points. Order is deliberate; see the class doc.
  static const List<(String, String)> points = [
    (
      'Meet at the meeting point. Stay somewhere public.',
      'Do not go anywhere private with someone you have just met, however '
          'well the evening is going.',
    ),
    (
      'Do not accept a ride home, and do not offer one.',
      'Leave the way you arrived. This is not about anyone here — it is a rule '
          'that works because nobody has to decide whether to apply it.',
    ),
    (
      'Tell someone where you are.',
      'One tap sends the place, the time and the end time to a contact you '
          'choose. Nothing else is shared with them, ever.',
    ),
    (
      'You can leave at any time, for any reason, with no explanation.',
      '“I am going to head off” is a complete sentence. Nobody will be told '
          'why, and it does not count against you.',
    ),
    (
      'Nobody here has been checked by us beyond a verified student identity.',
      'That is a real check and it is not a background check. We know they are '
          'a student at a Croatian university. We do not know anything else.',
    ),
    (
      'Report anything that felt wrong.',
      'It is private, the person is never told, and you will never be matched '
          'with them again — from the first report, before anyone reviews '
          'anything.',
    ),
    (
      'No advances, no flirting, no asking anyone out.',
      'This is a friend hangout. If you want the other thing, dating mode '
          'exists and it unlocks on its own.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = friendHangout ? points : points.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Before you go', style: ZarType.heading),
        const SizedBox(height: ZarSpace.xs),
        Text(
          'Every time. It takes twenty seconds and it is the part of this app '
          'that is actually about safety.',
          style: ZarType.body.copyWith(color: ZarColors.inkMuted),
        ),
        const SizedBox(height: ZarSpace.lg),
        for (final (index, (headline, detail)) in shown.indexed) ...[
          _Point(number: index + 1, headline: headline, detail: detail),
          if (index < shown.length - 1) const SizedBox(height: ZarSpace.md),
        ],
        const SizedBox(height: ZarSpace.xl),
        HoldToContinue(label: holdLabel, onComplete: onRead),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.number,
    required this.headline,
    required this.detail,
  });

  final int number;
  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Numbered because this is a fixed, countable list somebody may be told
      // to re-read — "point two" has to mean something. Elsewhere in the app
      // numbering would be decoration; here it is a reference.
      SizedBox(
        width: 26,
        child: Text(
          '$number',
          style: ZarType.monoKey.copyWith(color: ZarColors.ember),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: ZarType.bodyStrong),
            const SizedBox(height: 2),
            Text(
              detail,
              style: ZarType.body.copyWith(color: ZarColors.inkMuted),
            ),
          ],
        ),
      ),
    ],
  );
}
