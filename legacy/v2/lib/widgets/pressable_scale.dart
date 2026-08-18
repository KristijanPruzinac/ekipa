import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

/// The single tappable primitive. Springs down a touch on press and back on
/// release, with an optional soft haptic — so every interaction feels
/// physical without any of it feeling loud.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = true,
    this.scaleTo = EkipaMotion.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;
  final double scaleTo;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: EkipaMotion.fast,
    reverseDuration: EkipaMotion.fast,
    lowerBound: 0,
    upperBound: 1,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.scaleTo,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              _controller.forward();
              if (widget.haptic) HapticFeedback.lightImpact();
            },
      onTapUp: widget.onTap == null ? null : (_) => _controller.reverse(),
      onTapCancel: widget.onTap == null ? null : _controller.reverse,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
