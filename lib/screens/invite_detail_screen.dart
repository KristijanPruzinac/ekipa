import 'package:flutter/material.dart';
import '../data/format.dart';
import '../data/repository.dart';
import '../data/supabase_client.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/activity_icon.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/screen.dart';
import '../widgets/ticket_card.dart';

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
  String? _error;

  Future<void> _respond(bool accept) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    if (isBackendConfigured) {
      try {
        await repository.respond(widget.meetup.id, accept: accept);
      } catch (_) {
        // Do NOT proceed as if it worked — a phantom "accepted" that never
        // reached the server becomes a no-show, the one thing this product
        // can't survive. Surface it and let them tap again.
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = "That didn't go through — check your connection and try again.";
          });
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    accept ? widget.onAccept() : widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final meetup = widget.meetup;
    final alreadyResponded = meetup.myRsvp != 'pending';

    return Screen(
      backgroundAsset: 'assets/backgrounds/home_night.jpg',
      scrim: 0.3,
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
                if (_error != null) ...[
                  AppText(_error!, tone: EkipaTone.danger, center: true),
                  const SizedBox(height: EkipaSpace.sm),
                ],
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
      child: Appear(
        child: TicketCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero: activity icon + title + time.
              Center(
                child: Hero(
                  tag: 'activity-${meetup.id}',
                  child: Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3F5D3A), Color(0xFF2E4429)],
                      ),
                      borderRadius: BorderRadius.circular(EkipaRadius.lg),
                    ),
                    child: ActivityIcon(meetup.activitySlug,
                        size: 30, color: const Color(0xFFBFE0A8)),
                  ),
                ),
              ),
              const SizedBox(height: EkipaSpace.md),
              AppText(meetup.activityLabel,
                  variant: EkipaTextVariant.title,
                  tone: EkipaTone.paperInk,
                  center: true),
              const SizedBox(height: EkipaSpace.sm),
              AppText(
                '${formatWhen(meetup.startsAt)} · ${formatDuration(meetup.durationMin)}',
                variant: EkipaTextVariant.callout,
                tone: EkipaTone.paperSoft,
                center: true,
              ),
              const SizedBox(height: EkipaSpace.lg),
              const TicketPerforation(),
              const SizedBox(height: EkipaSpace.lg),

              _PaperSection(
                label: 'WHERE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(meetup.venueName,
                        variant: EkipaTextVariant.bodyStrong,
                        tone: EkipaTone.paperInk),
                    const SizedBox(height: 2),
                    AppText('${meetup.venueNote} · Public place.',
                        variant: EkipaTextVariant.callout,
                        tone: EkipaTone.paperSoft),
                  ],
                ),
              ),
              const SizedBox(height: EkipaSpace.lg),
              const TicketPerforation(),
              const SizedBox(height: EkipaSpace.lg),

              _PaperSection(
                label: 'WHAT TO EXPECT',
                child: AppText(meetup.whatToExpect,
                    variant: EkipaTextVariant.body, tone: EkipaTone.paperInk),
              ),
              const SizedBox(height: EkipaSpace.lg),
              const TicketPerforation(),
              const SizedBox(height: EkipaSpace.lg),

              _PaperSection(
                label: "WHO'S COMING",
                child: _WhosComing(meetup: meetup),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three states of "who's coming", in order of how much they reveal:
///   • names — inside the T−3h window, first names resolve
///   • shape — confirmed but pre-reveal: how many, what mix, no names
///   • private — not yet confirmed: nothing, not even a count
class _WhosComing extends StatelessWidget {
  const _WhosComing({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    if (meetup.attendees.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in meetup.attendees) ...[
            _PaperAttendee(name: a.firstName),
            if (a != meetup.attendees.last) const SizedBox(height: EkipaSpace.md),
          ],
        ],
      );
    }

    final comp = meetup.composition;
    if (meetup.status == GroupStatus.confirmed && comp != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(_countLine(comp),
              variant: EkipaTextVariant.bodyStrong, tone: EkipaTone.paperInk),
          if (_mixLine(comp) != null) ...[
            const SizedBox(height: 2),
            AppText(_mixLine(comp)!,
                variant: EkipaTextVariant.callout, tone: EkipaTone.paperSoft),
          ],
          const SizedBox(height: EkipaSpace.sm),
          const AppText(
            "First names appear three hours before you meet — close enough to be "
            "useful, too late to overthink.",
            variant: EkipaTextVariant.callout,
            tone: EkipaTone.paperSoft,
          ),
        ],
      );
    }

    return const AppText(
      "Private until everyone's in. As soon as the group is set, you'll see who's coming.",
      variant: EkipaTextVariant.callout,
      tone: EkipaTone.paperSoft,
    );
  }

  String _countLine(MeetupComposition c) {
    final n = c.total;
    return n == 1 ? 'One other person is coming.' : '$n people are coming.';
  }

  String? _mixLine(MeetupComposition c) {
    final parts = <String>[];
    if (c.women > 0) parts.add('${c.women} ${c.women == 1 ? 'woman' : 'women'}');
    if (c.men > 0) parts.add('${c.men} ${c.men == 1 ? 'man' : 'men'}');
    if (parts.isEmpty || parts.length == 1 && c.other == 0) {
      // A single-gender group is worth stating plainly; a mix of one kind only
      // with no "other" is already implied by the count, so skip it.
      if (parts.length == 1 && c.total == (c.women + c.men)) return parts.first;
      return null;
    }
    return parts.join(', ');
  }
}

class _PaperSection extends StatelessWidget {
  const _PaperSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, variant: EkipaTextVariant.label, tone: EkipaTone.paperMoss),
        const SizedBox(height: EkipaSpace.sm),
        child,
      ],
    );
  }
}

class _PaperAttendee extends StatelessWidget {
  const _PaperAttendee({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE3D5B8),
            border: Border.all(color: EkipaColors.paperLine),
          ),
          child: AppText(name[0],
              variant: EkipaTextVariant.bodyStrong, tone: EkipaTone.paperInk),
        ),
        const SizedBox(width: EkipaSpace.md),
        AppText(name,
            variant: EkipaTextVariant.bodyStrong, tone: EkipaTone.paperInk),
      ],
    );
  }
}
