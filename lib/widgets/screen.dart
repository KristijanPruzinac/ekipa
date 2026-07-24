import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import 'starfield.dart';

/// The single page frame for the whole app. Safe-area aware, calm padding,
/// optional pinned footer for the one primary action a screen should offer.
///
/// Each screen sits on a photographic dusk sky ([backgroundAsset]); when
/// [ambient] is set, a living [Starfield] (twinkling stars + warm shooting
/// trails) is layered on top so the sky is never static. A painted gradient
/// stands in when no asset is supplied (offline/demo, or during tests).
class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.child,
    this.scroll = true,
    this.footer,
    this.ambient = false,
    this.backgroundAsset,
    this.scrim = 0.0,
  });

  final Widget child;
  final bool scroll;
  final Widget? footer;
  final bool ambient;

  /// A full-bleed background image (e.g. 'assets/backgrounds/home_night.jpg').
  final String? backgroundAsset;

  /// Extra top-to-bottom dark scrim (0..1) for text legibility over busy skies.
  final double scrim;

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
          // Base layer: the photo, or a painted dusk gradient fallback.
          if (backgroundAsset != null)
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _gradientFallback(c),
              ),
            )
          else
            Positioned.fill(child: _gradientFallback(c)),

          // Optional legibility scrim, darker at the top where display text sits.
          if (scrim > 0)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: scrim),
                      Colors.black.withValues(alpha: scrim * 0.15),
                    ],
                  ),
                ),
              ),
            ),

          // Living sky overlay.
          if (ambient) const Positioned.fill(child: Starfield()),

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
                    child: SafeArea(top: false, child: footer!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientFallback(EkipaColors c) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bgGradientTop, c.bgGradientBottom, c.bgGradientTop],
        ),
      ),
    );
  }
}
