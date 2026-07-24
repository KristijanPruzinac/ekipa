import 'package:flutter/material.dart';
import '../data/format.dart';
import '../data/repository.dart';
import '../data/supabase_client.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/screen.dart';

class InviteDetailScreen extends StatefulWidget {
  const InviteDetailScreen({
    super.key,
    required this.meetup,
    required this.onAccept,
    required this.onDecline,
  });

  final Meetup meetup;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<InviteDetailScreen> createState() => _InviteDetailScreenState();
}

class _InviteDetailScreenState extends State<InviteDetailScreen> {
  bool _submitting = false;

  Future<void> _respond(bool accept) async {
    setState(() => _submitting = true);
    if (isBackendConfigured) {
      try {
        await repository.respond(widget.meetup.id, accept: accept);
      } catch (_) {
        // Best-effort: still let them proceed locally rather than strand
        // them on a network blip — their RSVP simply wasn't recorded.
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    accept ? widget.onAccept() : widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meetup = widget.meetup;
    final alreadyResponded = meetup.myRsvp != 'pending';
    final showAttendees = meetup.status == GroupStatus.confirmed && meetup.attendees.isNotEmpty;

    return Screen(
      footer: alreadyResponded
          ? AppText(
              meetup.myRsvp == 'yes'
                  ? "You said yes — we'll let you know once everyone's in."
                  : "You said not this time. That's between you and the app.",
              tone: EkipaTone.soft,
              center: true,
            )
          : Column(
              children: [
                AppButton(
                  label: "Yes, I'll come",
                  celebrate: true,
                  loading: _submitting,
                  onPressed: () => _respond(true),
                ),
                const SizedBox(height: EkipaSpace.sm),
                AppButton(
                  label: 'Not this time',
                  variant: EkipaButtonVariant.ghost,
                  loading: _submitting,
                  onPressed: () => _respond(false),
                ),
                const SizedBox(height: EkipaSpace.sm),
                const AppText(
                  "Saying no is completely private. No one is told, and it won't affect future invitations.",
                  variant: EkipaTextVariant.caption,
                  tone: EkipaTone.faint,
                  center: true,
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Appear(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
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
                    borderRadius: BorderRadius.circular(EkipaRadius.lg),
                    border: Border.all(color: c.moss.withValues(alpha: 0.25)),
                  ),
                  child: ActivityIcon(meetup.activitySlug, size: 30, color: c.mossGlow),
                ),
                const SizedBox(height: EkipaSpace.md),
                AppText(meetup.activityLabel, variant: EkipaTextVariant.title, center: true),
                const SizedBox(height: EkipaSpace.md),
                AppText(
                  '${formatWhen(meetup.startsAt)} – ${endTimeLabel(meetup.startsAt, meetup.durationMin)}   ·   ${formatDuration(meetup.durationMin)}',
                  tone: EkipaTone.soft,
                  center: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: EkipaSpace.xl),
          Appear(
            delay: const Duration(milliseconds: 80),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('WHERE', variant: EkipaTextVariant.label, tone: EkipaTone.moss),
                  const SizedBox(height: EkipaSpace.xs),
                  AppText(meetup.venueName, variant: EkipaTextVariant.bodyStrong),
                  const SizedBox(height: 2),
                  AppText('${meetup.venueNote} · Public place.', variant: EkipaTextVariant.callout, tone: EkipaTone.soft),
                ],
              ),
            ),
          ),
          const SizedBox(height: EkipaSpace.md),
          Appear(
            delay: const Duration(milliseconds: 150),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('WHAT TO EXPECT', variant: EkipaTextVariant.label, tone: EkipaTone.moss),
                  const SizedBox(height: EkipaSpace.sm),
                  AppText(meetup.whatToExpect, tone: EkipaTone.soft),
                ],
              ),
            ),
          ),
          const SizedBox(height: EkipaSpace.md),
          Appear(
            delay: const Duration(milliseconds: 220),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText("WHO'S COMING", variant: EkipaTextVariant.label, tone: EkipaTone.mossGlow),
                  const SizedBox(height: EkipaSpace.md),
                  if (showAttendees)
                    for (final a in meetup.attendees) ...[
                      _AttendeeRow(attendee: a),
                      if (a != meetup.attendees.last) const SizedBox(height: EkipaSpace.lg),
                    ]
                  else
                    const AppText(
                      "Private until everyone accepts. As soon as the group is set, you'll see who's in.",
                      tone: EkipaTone.faint,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({required this.attendee});

  final Attendee attendee;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.glassStrong,
            border: Border.all(color: c.line),
          ),
          child: AppText(attendee.firstName[0], variant: EkipaTextVariant.bodyStrong, tone: EkipaTone.soft),
        ),
        const SizedBox(width: EkipaSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(attendee.firstName, variant: EkipaTextVariant.bodyStrong),
              AppText(attendee.blurb, variant: EkipaTextVariant.callout, tone: EkipaTone.faint),
            ],
          ),
        ),
      ],
    );
  }
}
