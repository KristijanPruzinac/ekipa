import 'package:flutter/material.dart';
import '../data/format.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenMeetup});

  final void Function(Meetup meetup) onOpenMeetup;

  @override
  Widget build(BuildContext context) {
    return Screen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('OSIJEK', variant: EkipaTextVariant.label, tone: EkipaTone.moss),
          const SizedBox(height: EkipaSpace.xs),
          const AppText('A new invitation', variant: EkipaTextVariant.title),
          const SizedBox(height: EkipaSpace.xl),
          Appear(
            delay: const Duration(milliseconds: 80),
            child: _InviteCard(meetup: mockMeetup, hero: true, onTap: () => onOpenMeetup(mockMeetup)),
          ),
          const SizedBox(height: EkipaSpace.xxl),
          Appear(
            delay: const Duration(milliseconds: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('YOUR STANDING GROUP', variant: EkipaTextVariant.label, tone: EkipaTone.faint),
                const SizedBox(height: EkipaSpace.md),
                _InviteCard(meetup: mockStanding, onTap: () => onOpenMeetup(mockStanding)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.meetup, required this.onTap, this.hero = false});

  final Meetup meetup;
  final VoidCallback onTap;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final names = meetup.attendees.map((a) => a.firstName).join(', ');

    return PressableScale(
      onTap: onTap,
      child: AppCard(
        emphasis: hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
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
            const SizedBox(height: EkipaSpace.md),
            AppText(
              meetup.status == GroupStatus.confirmed ? 'Confirmed · every other week →' : 'Tap to see the plan →',
              variant: EkipaTextVariant.calloutStrong,
              tone: hero ? EkipaTone.mossGlow : EkipaTone.faint,
            ),
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
