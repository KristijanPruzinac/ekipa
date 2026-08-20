import 'package:ekipa_ui/src/primitives/pressable.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// What a chip is saying.
enum ZarChipTone {
  /// A neutral fact about a place or a hangout: `outdoor`, `step-free`.
  plain,

  /// Something good is true: confirmed, arrived, open.
  good,

  /// Something is pending or close: waiting, closing soon.
  waiting,

  /// Something is wrong: cancelled, declined, closed.
  wrong,

  /// The live thing.
  live,
}

/// A small immutable fact, worn by a place or a hangout.
///
/// Taken from `docs/reference/places/04-place-detail` — the frame the reference
/// notes call *"the single most directly reusable frame in the set"*. Chips do
/// the work an icon row would do, in words, which is the right trade for a
/// product with no icon set and two languages to serve.
class ZarChip extends StatelessWidget {
  /// A chip reading [label].
  const ZarChip(
    this.label, {
    this.tone = ZarChipTone.plain,
    this.dot = false,
    super.key,
  });

  /// The text. Short — two words at most.
  final String label;

  /// What it means.
  final ZarChipTone tone;

  /// Whether to draw a status dot before the label.
  final bool dot;

  Color get _ink => switch (tone) {
    ZarChipTone.plain => ZarColors.inkMuted,
    ZarChipTone.good => ZarColors.mint,
    ZarChipTone.waiting => ZarColors.amber,
    ZarChipTone.wrong => ZarColors.rose,
    ZarChipTone.live => ZarColors.ember,
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: ZarRadius.allPill,
      color: tone == ZarChipTone.plain
          ? ZarColors.surfaceRaised
          : _ink.withValues(alpha: 0.10),
      border: Border.all(
        color: tone == ZarChipTone.plain
            ? ZarColors.hairline
            : _ink.withValues(alpha: 0.26),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZarSpace.sm,
        vertical: ZarSpace.xxs + 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _ink),
            ),
            const SizedBox(width: ZarSpace.xs),
          ],
          Text(label, style: ZarType.caption.copyWith(color: _ink)),
        ],
      ),
    ),
  );
}

/// A full-width answer to a one-question screen.
///
/// The reference set is unanimous that onboarding asks one thing per screen
/// (`docs/reference/README.md`), and a one-question screen wants rows, not a
/// dropdown: every option is visible, the tap target is the whole row, and
/// nothing is hidden behind an interaction.
class ZarChoice extends StatelessWidget {
  /// A row reading [label], optionally with a [note] beneath it.
  const ZarChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.note,
    super.key,
  });

  /// The answer.
  final String label;

  /// A supporting line, when the answer needs one.
  final String? note;

  /// Whether this is the current answer.
  final bool selected;

  /// Chooses it.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onPressed,
    semanticLabel: note == null ? label : '$label. $note',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? ZarColors.emberWash : ZarColors.surface,
        borderRadius: ZarRadius.allMd,
        border: Border.all(
          color: selected ? ZarColors.ember : ZarColors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZarSpace.md,
          vertical: ZarSpace.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ZarType.body.copyWith(
                      color: ZarColors.ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: ZarType.caption.copyWith(
                        color: ZarColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: ZarSpace.sm),
            _Tick(on: selected),
          ],
        ),
      ),
    ),
  );
}

/// A time a person can say yes to.
///
/// Wider than it needs to be on purpose: `ZarLayout.minTapTarget` is a floor,
/// and this is a control people tap nine times in a row on a phone held in one
/// hand.
class ZarTimeChip extends StatelessWidget {
  /// A chip for [time], e.g. `17:30`.
  const ZarTimeChip({
    required this.time,
    required this.selected,
    required this.onPressed,
    this.note,
    this.density = 0,
    super.key,
  });

  /// The local start time.
  final String time;

  /// A line under it — how long, or how likely.
  final String? note;

  /// Whether the person has said yes.
  final bool selected;

  /// Toggles it.
  final VoidCallback onPressed;

  /// `0…1` chance of a hangout at this time. Drawn as a wash behind the time.
  final double density;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onPressed,
    semanticLabel: '$time${selected ? ', chosen' : ''}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? ZarColors.ember
            : density > 0
            ? ZarColors.ember.withValues(
                alpha: 0.05 + 0.14 * density.clamp(0, 1),
              )
            : ZarColors.surface,
        borderRadius: ZarRadius.allMd,
        border: Border.all(
          color: selected ? ZarColors.ember : ZarColors.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZarSpace.md,
          vertical: ZarSpace.sm + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: ZarType.bodyStrong.copyWith(
                color: selected ? ZarColors.emberInk : ZarColors.ink,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              // One line, always. Three of these sit side by side in a row, and
              // a note that wraps in one chip and not the others makes the row
              // ragged — which reads as three different controls rather than
              // three times on one evening.
              Text(
                note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: ZarType.caption.copyWith(
                  color: selected
                      ? ZarColors.emberInk.withValues(alpha: 0.75)
                      : ZarColors.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The chosen mark.
///
/// Drawn rather than `Icons.check`: the design system ships no icon font, and a
/// Material glyph would be the one thing on screen that came from somewhere
/// else. It also renders in tests, where an icon font does not.
class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 22,
    child: CustomPaint(painter: _TickPainter(on: on)),
  );
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.on});

  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    if (!on) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = ZarColors.hairline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      return;
    }
    canvas.drawCircle(centre, radius, Paint()..color = ZarColors.ember);
    final tick = Paint()
      ..color = ZarColors.emberInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.29, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.67)
        ..lineTo(size.width * 0.72, size.height * 0.35),
      tick,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.on != on;
}
