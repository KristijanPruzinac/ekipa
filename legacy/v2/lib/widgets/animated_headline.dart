import 'package:flutter/material.dart';
import '../theme/text_styles.dart';
import 'app_text.dart';

/// A headline whose characters settle into place one after another — a gentle
/// fade + rise + un-blur, staggered left to right. Used for the big display
/// beats ("You're in.", "A new invitation") so the first thing you see is
/// alive, not stamped down.
///
/// Falls back to an instant [AppText] when the platform asks for reduced
/// motion, so it never costs accessibility.
class AnimatedHeadline extends StatefulWidget {
  const AnimatedHeadline(
    this.text, {
    super.key,
    this.variant = EkipaTextVariant.display,
    this.tone = EkipaTone.normal,
    this.center = false,
    this.style,
    this.delay = Duration.zero,
    this.perCharacter = 30,
  });

  final String text;
  final EkipaTextVariant variant;
  final EkipaTone tone;
  final bool center;
  final TextStyle? style;
  final Duration delay;

  /// Milliseconds of stagger between each character's start.
  final int perCharacter;

  @override
  State<AnimatedHeadline> createState() => _AnimatedHeadlineState();
}

class _AnimatedHeadlineState extends State<AnimatedHeadline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _count = widget.text.characters.length;

  @override
  void initState() {
    super.initState();
    // Total time = last char's start + its own tween window.
    final total = widget.delay.inMilliseconds +
        _count * widget.perCharacter +
        360;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final baseStyle = widget.variant.style;

    if (reduceMotion) {
      return AppText(
        widget.text,
        variant: widget.variant,
        tone: widget.tone,
        center: widget.center,
        style: widget.style,
      );
    }

    final total = _controller.duration!.inMilliseconds;
    final chars = widget.text.characters.toList();

    // The per-character split is a visual effect only; expose the whole
    // string as one label to assistive tech and hide the fragments.
    return Semantics(
      label: widget.text,
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Wrap(
              alignment:
                  widget.center ? WrapAlignment.center : WrapAlignment.start,
              children: [
                for (var i = 0; i < chars.length; i++)
                  _AnimatedChar(
                    char: chars[i],
                    progress: _charProgress(i, total),
                    variant: widget.variant,
                    tone: widget.tone,
                    style: widget.style ?? const TextStyle(),
                    baseStyle: baseStyle,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _charProgress(int i, int total) {
    final startMs = widget.delay.inMilliseconds + i * widget.perCharacter;
    final windowMs = 360.0;
    final nowMs = _controller.value * total;
    return ((nowMs - startMs) / windowMs).clamp(0.0, 1.0);
  }
}

class _AnimatedChar extends StatelessWidget {
  const _AnimatedChar({
    required this.char,
    required this.progress,
    required this.variant,
    required this.tone,
    required this.style,
    required this.baseStyle,
  });

  final String char;
  final double progress;
  final EkipaTextVariant variant;
  final EkipaTone tone;
  final TextStyle style;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    // Preserve spaces as real width even before they "arrive".
    final isSpace = char.trim().isEmpty;
    return Opacity(
      opacity: isSpace ? 1.0 : eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 10),
        child: AppText(
          char == ' ' ? ' ' : char,
          variant: variant,
          tone: tone,
          style: style,
        ),
      ),
    );
  }
}
