import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/screen.dart';

/// Arrival. No onboarding screens, no forms, no chip-picker — you sign in
/// and you're immediately ready. This screen IS the zero-onboarding promise:
/// it explains that nothing further is asked of you before your first
/// invitation arrives.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Screen(
      scroll: false,
      ambient: true,
      footer: Column(
        children: [
          AppButton(label: 'See my invitation', onPressed: onContinue),
          const SizedBox(height: EkipaSpace.sm),
          const AppText(
            'Osijek · walking, board games, and quiet company',
            variant: EkipaTextVariant.caption,
            tone: EkipaTone.faint,
            center: true,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Appear(
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.ink, c.ink.withValues(alpha: 0.55)],
                ).createShader(rect),
                child: const AppText(
                  'You\'re in.',
                  variant: EkipaTextVariant.display,
                ),
              ),
            ),
            const SizedBox(height: EkipaSpace.sm),
            Appear(
              delay: const Duration(milliseconds: 90),
              child: const AppText(
                'We\'ll come to you.',
                variant: EkipaTextVariant.thesis,
                tone: EkipaTone.soft,
              ),
            ),
            const SizedBox(height: EkipaSpace.xl),
            Appear(
              delay: const Duration(milliseconds: 180),
              child: AppCard(
                child: Row(
                  children: [
                    _PulseDot(color: c.ember),
                    const SizedBox(width: EkipaSpace.md),
                    const Expanded(
                      child: AppText(
                        'Waiting for your first invitation — usually within a week.',
                        variant: EkipaTextVariant.callout,
                        tone: EkipaTone.soft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: EkipaSpace.lg),
            Appear(
              delay: const Duration(milliseconds: 260),
              child: const AppText(
                'No profile to fill out. No one to message. When a small group '
                'forms nearby, you\'ll just get asked: in or not.',
                tone: EkipaTone.faint,
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.7),
              blurRadius: 10,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
