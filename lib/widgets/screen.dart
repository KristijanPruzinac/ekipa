import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import 'constellation_field.dart';

/// The single page frame for the whole app. Safe-area aware, calm padding,
/// optional pinned footer for the one primary action a screen should offer.
/// Every screen sits on the same dusk ground with a faint moss ambient glow
/// — ember is deliberately absent here, reserved for the arrival pulse and
/// the commitment button. [ambient] additionally layers the animated
/// constellation field for screens where that atmosphere should be the star
/// (Welcome).
class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.child,
    this.scroll = true,
    this.footer,
    this.ambient = false,
  });

  final Widget child;
  final bool scroll;
  final Widget? footer;
  final bool ambient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const padding = EdgeInsets.symmetric(
      horizontal: EkipaSpace.xl,
      vertical: EkipaSpace.xl,
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.bgGradientTop, c.bgGradientBottom, c.bgGradientTop],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.4),
                  radius: 0.9,
                  colors: [c.moss.withValues(alpha: 0.07), Colors.transparent],
                ),
              ),
            ),
          ),
          if (ambient) const Positioned.fill(child: ConstellationField()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: scroll
                      ? SingleChildScrollView(padding: padding, child: child)
                      : Padding(padding: padding, child: child),
                ),
                if (footer != null)
                  Container(
                    padding: const EdgeInsets.only(
                      left: EkipaSpace.xl,
                      right: EkipaSpace.xl,
                      top: EkipaSpace.md,
                      bottom: EkipaSpace.lg,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.lineSoft)),
                    ),
                    child: SafeArea(top: false, child: footer!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
