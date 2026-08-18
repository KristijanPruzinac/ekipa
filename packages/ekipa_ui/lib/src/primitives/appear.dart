import 'package:ekipa_ui/src/tokens/motion.dart';
import 'package:flutter/widgets.dart';

/// A staggered entrance: fade up, a little, once.
///
/// Carried from the v1 kit (`LEGACY_AUDIT.md` §4). The job is to give a screen
/// an order — the eye is told what to read first — without anything appearing
/// to move. Offset is 8 logical pixels, which reads as settling rather than
/// sliding.
///
/// *Rejected — animating on every rebuild:* a list that re-animates when a
/// value changes is the single most common way this effect turns from
/// atmosphere into noise. [Appear] runs once, on mount, and never again.
class Appear extends StatefulWidget {
  /// Wraps [child] in a one-shot entrance, delayed by [index] stagger steps.
  const Appear({
    required this.child,
    this.index = 0,
    this.duration = ZarMotion.base,
    super.key,
  });

  /// The thing arriving.
  final Widget child;

  /// Position in the stagger. Item `n` starts `n · ZarMotion.stagger` late.
  final int index;

  /// How long the arrival takes.
  final Duration duration;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _eased = CurvedAnimation(
    parent: _controller,
    curve: ZarMotion.entering,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Read once, here rather than in build: someone who turns reduced motion on
    // mid-animation should not have the animation snap under them, and someone
    // who has it on from the start should never see a frame of movement.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(ZarMotion.stagger * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _eased,
    builder: (context, child) => Opacity(
      opacity: _eased.value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - _eased.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Wraps each of [children] in an [Appear] with an increasing stagger index.
///
/// Exists so a column does not have to hand-number its own children, which is
/// where the numbers drift when someone inserts a row in the middle.
List<Widget> staggered(List<Widget> children, {int from = 0}) => [
  for (var i = 0; i < children.length; i++)
    Appear(index: from + i, child: children[i]),
];
