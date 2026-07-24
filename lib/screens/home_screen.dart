import 'package:flutter/material.dart';
import '../data/format.dart';
import '../data/mock_data.dart';
import '../data/repository.dart';
import '../data/supabase_client.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/animated_headline.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/screen.dart';
import '../widgets/ticket_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenMeetup});

  final void Function(Meetup meetup) onOpenMeetup;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Meetup>> _invitations;

  @override
  void initState() {
    super.initState();
    _invitations = isBackendConfigured
        ? repository.myInvitations()
        : Future.value([mockMeetup, mockFormingConfirmed, mockStanding]);
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      backgroundAsset: 'assets/backgrounds/home_night.jpg',
      scrim: 0.25,
      child: FutureBuilder<List<Meetup>>(
        future: _invitations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.only(top: EkipaSpace.xxxl),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final meetups = snapshot.data ?? const [];
          final standing = meetups.where((m) => m.isStanding).toList();
          final fresh = meetups.where((m) => !m.isStanding).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('OSIJEK', variant: EkipaTextVariant.label, tone: EkipaTone.moss),
              const SizedBox(height: EkipaSpace.xs),
              const AnimatedHeadline('A new invitation', variant: EkipaTextVariant.title),
              const SizedBox(height: EkipaSpace.xl),
              if (fresh.isEmpty)
                const Appear(
                  delay: Duration(milliseconds: 80),
                  child: AppText(
                    "Nothing yet — usually within a week. We'll let you know the moment "
                    "something comes together nearby.",
                    tone: EkipaTone.soft,
                  ),
                )
              else
                for (var i = 0; i < fresh.length; i++) ...[
                  if (i > 0) const SizedBox(height: EkipaSpace.lg),
                  Appear(
                    delay: Duration(milliseconds: 80 + i * 90),
                    child: _PaperInviteCard(
                      meetup: fresh[i],
                      onTap: () => widget.onOpenMeetup(fresh[i]),
                    ),
                  ),
                ],
              if (standing.isNotEmpty) ...[
                const SizedBox(height: EkipaSpace.xxl),
                Appear(
                  delay: const Duration(milliseconds: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('YOUR STANDING GROUP', variant: EkipaTextVariant.label, tone: EkipaTone.faint),
                      const SizedBox(height: EkipaSpace.md),
                      _InviteCard(meetup: standing.first, onTap: () => widget.onOpenMeetup(standing.first)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.meetup, required this.onTap});

  final Meetup meetup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final names = meetup.attendees.map((a) => a.firstName).join(', ');

    return PressableScale(
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'activity-${meetup.id}',
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          c.moss.withValues(alpha: 0.22),
                          c.moss.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(EkipaRadius.md),
                      border: Border.all(color: c.moss.withValues(alpha: 0.25)),
                    ),
                    child: ActivityIcon(meetup.activitySlug, size: 24, color: c.mossGlow),
                  ),
                ),
                const SizedBox(width: EkipaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(meetup.activityLabel, variant: EkipaTextVariant.heading),
                      AppText(meetup.venueName, variant: EkipaTextVariant.callout, tone: EkipaTone.soft),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: EkipaSpace.lg),
              child: Divider(height: 1, color: c.lineSoft),
            ),
            _Row(label: 'When', value: formatWhen(meetup.startsAt)),
            const SizedBox(height: EkipaSpace.sm),
            _Row(label: 'For', value: formatDuration(meetup.durationMin)),
            if (meetup.status == GroupStatus.confirmed && meetup.attendees.isNotEmpty) ...[
              const SizedBox(height: EkipaSpace.md),
              Row(
                children: [
                  for (var i = 0; i < meetup.attendees.length; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 14),
                      child: _MiniAvatar(letter: meetup.attendees[i].firstName[0]),
                    ),
                  const SizedBox(width: EkipaSpace.sm),
                  Expanded(
                    child: AppText(
                      names,
                      variant: EkipaTextVariant.caption,
                      tone: EkipaTone.faint,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: EkipaSpace.md),
            AppText(
              meetup.status == GroupStatus.confirmed ? 'Confirmed · every other week →' : 'Tap to see the plan →',
              variant: EkipaTextVariant.calloutStrong,
              tone: EkipaTone.faint,
            ),
          ],
        ),
      ),
    );
  }
}

/// A fresh invitation on Home, rendered as a compact paper ticket — the same
/// tactile "handed to you" stock as the detail screen, so tapping through feels
/// like turning the ticket over rather than jumping worlds. The standing group
/// stays dark glass; only genuinely new invitations get the paper.
class _PaperInviteCard extends StatelessWidget {
  const _PaperInviteCard({required this.meetup, required this.onTap});

  final Meetup meetup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: TicketCard(
        padding: const EdgeInsets.all(EkipaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'activity-${meetup.id}',
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [EkipaColors.paperTileTop, EkipaColors.paperTileBottom],
                      ),
                      borderRadius: BorderRadius.circular(EkipaRadius.md),
                    ),
                    child: ActivityIcon(meetup.activitySlug,
                        size: 24, color: EkipaColors.paperTileGlyph),
                  ),
                ),
                const SizedBox(width: EkipaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(meetup.activityLabel,
                          variant: EkipaTextVariant.heading,
                          tone: EkipaTone.paperInk),
                      AppText(meetup.venueName,
                          variant: EkipaTextVariant.callout,
                          tone: EkipaTone.paperSoft),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EkipaSpace.md),
            const TicketPerforation(),
            const SizedBox(height: EkipaSpace.md),
            AppText(
              '${formatWhen(meetup.startsAt)} · ${formatDuration(meetup.durationMin)}',
              variant: EkipaTextVariant.callout,
              tone: EkipaTone.paperInk,
            ),
            const SizedBox(height: EkipaSpace.sm),
            const AppText('Tap to see the plan →',
                variant: EkipaTextVariant.calloutStrong,
                tone: EkipaTone.paperEmber),
          ],
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.glassStrong, c.glass],
        ),
        border: Border.all(color: c.line),
      ),
      child: AppText(letter, variant: EkipaTextVariant.calloutStrong, tone: EkipaTone.soft),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: AppText(label, variant: EkipaTextVariant.callout, tone: EkipaTone.faint),
        ),
        const SizedBox(width: EkipaSpace.md),
        Expanded(
          child: AppText(value, variant: EkipaTextVariant.callout, tone: EkipaTone.soft),
        ),
      ],
    );
  }
}
