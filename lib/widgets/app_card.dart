import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

/// The glass content container. Real depth via backdrop blur, an inner
/// highlight, and a soft outer glow — not a flat filled rectangle.
/// [emphasis] gives the moss gradient wash + glow border for the "this is
/// your invitation" hero card.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.emphasis = false,
    this.padding = const EdgeInsets.all(EkipaSpace.xl),
  });

  final Widget child;
  final bool emphasis;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(EkipaRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: emphasis
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.moss.withValues(alpha: 0.16),
                      c.moss.withValues(alpha: 0.04),
                    ],
                  )
                : null,
            color: emphasis ? null : c.glass,
            borderRadius: BorderRadius.circular(EkipaRadius.xl),
            border: Border.all(
              color: emphasis ? c.moss.withValues(alpha: 0.35) : c.line,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: emphasis
                    ? c.moss.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: emphasis ? 44 : 28,
                offset: const Offset(0, 16),
                spreadRadius: emphasis ? -12 : -10,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
