import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// A button that has to be held.
///
/// **Intention — the one control in the product that refuses a reflex.** D12
/// makes the safety brief mandatory and unskippable, and says it must be *"read
/// past, not dismissed by reflex — a short deliberate scroll or a
/// hold-to-continue, never a checkbox that a thumb finds without the eyes"*.
///
/// A checkbox is found by muscle memory in under a second and carries no
/// information about whether anyone read anything. A hold does two things a tap
/// cannot: it costs a measurable amount of attention, and the progress arc puts
/// the cost on screen so the delay reads as deliberate rather than broken.
///
/// **Why not a timed unlock instead** (button disabled for six seconds): a
/// disabled button is a thing to wait out while looking elsewhere. Holding
/// keeps a thumb on the glass and eyes on the screen for the whole duration,
/// which is the entire point.
///
/// Releasing early rewinds rather than resets — the intent was there, the grip
/// slipped, and punishing that teaches people to resent the screen that exists
/// to keep them safe.
class HoldToContinue extends StatefulWidget {
  /// A hold-to-continue control reading [label].
  const HoldToContinue({
    required this.label,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 1600),
    this.hint = 'Press and hold',
    super.key,
  });

  /// What happens when it completes.
  final String label;

  /// Called once, when the hold finishes.
  final VoidCallback onComplete;

  /// How long the hold takes.
  final Duration duration;

  /// The line beneath, telling people what to do. Never omit it: an unlabelled
  /// control that ignores taps is indistinguishable from a broken one.
  final String hint;

  @override
  State<HoldToContinue> createState() => _HoldToContinueState();
}

class _HoldToContinueState extends State<HoldToContinue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(
        vsync: this,
        duration: widget.duration,
        reverseDuration: const Duration(milliseconds: 260),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_fired) {
          _fired = true;
          widget.onComplete();
        }
      });

  bool _fired = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _hold() {
    if (_fired) return;
    _progress.forward();
  }

  void _release() {
    if (_fired) return;
    _progress.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // A screen reader user cannot hold a button they cannot see the progress
    // of, and making safety information harder to get past for someone using
    // assistive technology would be the exact opposite of the intention. The
    // semantic control is an ordinary button.
    return Semantics(
      button: true,
      label: widget.label,
      onTap: () {
        if (_fired) return;
        _fired = true;
        widget.onComplete();
      },
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _hold(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => SizedBox(
                height: ZarLayout.controlHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HoldPainter(progress: _progress.value),
                  child: Center(
                    child: Text(
                      widget.label,
                      style: ZarType.bodyStrong.copyWith(
                        color: _progress.value > 0.55
                            ? ZarColors.emberInk
                            : ZarColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZarSpace.xs),
            Text(
              widget.hint,
              style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldPainter extends CustomPainter {
  _HoldPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas
      ..drawRRect(shape, Paint()..color = ZarColors.surfaceRaised)
      ..save()
      ..clipRRect(shape)
      // The fill sweeps from the left rather than pulsing or spinning: it is a
      // measure of how much is left, and a person should be able to tell at a
      // glance whether letting go now costs them anything.
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width * progress, size.height),
        Paint()..color = ZarColors.ember,
      )
      ..restore()
      ..drawRRect(
        shape,
        Paint()
          ..color = progress > 0 ? ZarColors.ember : ZarColors.hairline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_HoldPainter old) => old.progress != progress;
}
