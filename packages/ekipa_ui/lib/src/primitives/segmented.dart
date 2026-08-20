import 'package:ekipa_ui/src/primitives/pressable.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/motion.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// One segment of a [SegmentedTabs].
@immutable
final class Segment {
  /// A segment reading [label].
  const Segment({required this.label, this.locked = false, this.lockedNote});

  /// What it says.
  final String label;

  /// Whether it is visible but not yet available.
  final bool locked;

  /// What to say when somebody taps a locked segment.
  final String? lockedNote;
}

/// The product's two modes, side by side.
///
/// **Intention — the transcript asks for this explicitly:** *"Make dating a
/// separate tab up top to the normal meet tab."* The shape comes from
/// Polarsteps' plan/track control
/// (`docs/reference/polarsteps/04-trip-map-plan`), which the reference notes
/// already identify as mapping cleanly onto our two tabs.
///
/// **A locked tab is shown, not hidden.** Dating unlocks after four to eight
/// hangouts (`07_DATING.md §4`). Hiding it until then would make it appear one
/// day out of nowhere; showing it locked makes the unlock a thing you can see
/// coming, which is the difference between a reward and a surprise. Tapping it
/// says what it is waiting for rather than doing nothing.
class SegmentedTabs extends StatelessWidget {
  /// Draws [segments], with [index] current.
  const SegmentedTabs({
    required this.segments,
    required this.index,
    required this.onChanged,
    this.onLockedPressed,
    super.key,
  });

  /// Two or three, no more. A segmented control with five segments is a tab bar
  /// that has not admitted it.
  final List<Segment> segments;

  /// Which one is showing.
  final int index;

  /// Switches to an available segment.
  final void Function(int index) onChanged;

  /// Called when a locked segment is tapped, with its note.
  final void Function(Segment segment)? onLockedPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZarColors.surface,
      borderRadius: ZarRadius.allPill,
      border: Border.all(color: ZarColors.hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final (position, segment) in segments.indexed)
            Expanded(
              child: Pressable(
                scale: 0.99,
                onPressed: () => segment.locked
                    ? onLockedPressed?.call(segment)
                    : onChanged(position),
                semanticLabel: segment.locked
                    ? '${segment.label}, locked'
                    : segment.label,
                child: AnimatedContainer(
                  duration: ZarMotion.quick,
                  curve: ZarMotion.standard,
                  height: 40,
                  decoration: BoxDecoration(
                    color: position == index
                        ? ZarColors.surfaceRaised
                        : const Color(0x00000000),
                    borderRadius: ZarRadius.allPill,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          segment.label,
                          style: ZarType.label.copyWith(
                            color: segment.locked
                                ? ZarColors.inkFaint
                                : position == index
                                ? ZarColors.ink
                                : ZarColors.inkMuted,
                          ),
                        ),
                        if (segment.locked) ...[
                          const SizedBox(width: ZarSpace.xxs + 2),
                          const _Padlock(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A drawn padlock. Same reasoning as the tick in `zar_chip.dart`: no icon font
/// in this design system, and a glyph that does not render in a test is a glyph
/// nothing can check.
class _Padlock extends StatelessWidget {
  const _Padlock();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 11,
    height: 13,
    child: CustomPaint(painter: _PadlockPainter()),
  );
}

class _PadlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = ZarColors.inkFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final shackle = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.05,
      size.width * 0.56,
      size.height * 0.52,
    );
    canvas
      ..drawArc(shackle, 3.14159, 3.14159, false, line)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
          const Radius.circular(2),
        ),
        Paint()..color = ZarColors.inkFaint,
      );
  }

  @override
  bool shouldRepaint(_PadlockPainter old) => false;
}
