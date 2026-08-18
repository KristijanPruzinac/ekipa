import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/repository.dart';
import '../data/supabase_client.dart';
import '../models/models.dart';
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
///
/// This is also the app's root route (see router.dart), so a returning user
/// lands here too — not just on first signup. It reads the same invitations
/// Home does and shows one of two states: still waiting, or something's
/// arrived. The "no profile, no messaging" reassurance only makes sense the
/// first time, so it's dropped once there's an actual invite to look at.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  List<Meetup> _fresh = const [];

  @override
  void initState() {
    super.initState();
    final invitations = isBackendConfigured
        ? repository.myInvitations()
        : Future.value([mockMeetup, mockFormingConfirmed, mockStanding]);
    invitations.then((meetups) {
      if (!mounted) return;
      setState(() => _fresh = meetups.where((m) => !m.isStanding).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasInvite = _fresh.isNotEmpty;
    final buttonLabel = _fresh.length > 1 ? 'See my invitations' : 'See my invitation';

    return Screen(
      scroll: false,
      ambient: true,
      backgroundAsset: 'assets/backgrounds/welcome_dusk.png',
      scrim: 0.28,
      footer: Column(
        children: [
          AppButton(label: buttonLabel, onPressed: widget.onContinue),
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
              child: AppText(
                hasInvite
                    ? (_fresh.length == 1 ? 'Your invitation is here.' : '${_fresh.length} invitations are waiting.')
                    : 'We\'ll come to you.',
                variant: EkipaTextVariant.thesis,
                tone: EkipaTone.soft,
              ),
            ),
            const SizedBox(height: EkipaSpace.xl),
            Appear(
              delay: const Duration(milliseconds: 180),
              child: AppCard(
                soft: true,
                child: Row(
                  children: [
                    _PulseDot(color: c.ember, active: hasInvite),
                    const SizedBox(width: EkipaSpace.md),
                    Expanded(
                      child: AppText(
                        hasInvite ? _teaser(_fresh) : 'Waiting for your first invitation — usually within a week.',
                        variant: EkipaTextVariant.callout,
                        tone: EkipaTone.soft,
                        style: TextStyle(
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!hasInvite) ...[
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
        ],
      ),
    );
  }

  String _teaser(List<Meetup> fresh) {
    final first = fresh.first;
    final more = fresh.length > 1 ? ' · +${fresh.length - 1} more' : '';
    return '${first.activityLabel} · ${first.venueName}$more';
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.active = false});

  final Color color;

  /// A quicker, higher-contrast pulse for "something's actually here" — the
  /// slow breathing dot reads as calm waiting, this reads as alive/new.
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.active ? 1200 : 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: widget.active ? 0.55 : 0.35).animate(
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
