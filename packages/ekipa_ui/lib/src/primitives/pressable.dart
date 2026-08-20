import 'package:ekipa_ui/src/tokens/motion.dart';
import 'package:flutter/widgets.dart';

/// Scales its child down slightly while a finger is on it.
///
/// The feedback vocabulary for the whole product, in place of Material's ink
/// ripple. *Why replace the ripple:* a ripple is a splash of the accent colour
/// on every tap, and in a palette where the accent means "this is the live
/// thing", spending it on every tap costs the accent its meaning.
///
/// Not exported as a primitive in its own right — it is the mechanism behind
/// `EkipaButton` and a tappable `EkipaCard`, and a screen that reaches for it
/// directly is usually about to build a button that is not the button.
class Pressable extends StatefulWidget {
  /// Wraps [child] so it responds to a press.
  const Pressable({
    required this.child,
    this.onPressed,
    this.scale = 0.97,
    this.semanticLabel,
    super.key,
  });

  /// The thing being pressed.
  final Widget child;

  /// What happens on a tap. `null` disables the press entirely, including the
  /// scale — a control that reacts but does nothing is worse than one that does
  /// not react.
  final VoidCallback? onPressed;

  /// How far down it goes while held.
  final double scale;

  /// What a screen reader announces. Defaults to the child's own semantics.
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      // When this wrapper supplies the label, the child's own text must not be
      // announced as well — otherwise a screen reader reads "Confirm,
      // Confirm", which is the kind of defect that is invisible to everyone
      // who does not depend on it.
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: _enabled ? (_) => _setDown(true) : null,
        onTapUp: _enabled ? (_) => _setDown(false) : null,
        onTapCancel: _enabled ? () => _setDown(false) : null,
        child: AnimatedScale(
          scale: _down && _enabled ? widget.scale : 1,
          duration: ZarMotion.scale(
            ZarMotion.quick,
            reduceMotion: reduceMotion,
          ),
          curve: ZarMotion.entering,
          child: widget.child,
        ),
      ),
    );
  }
}
