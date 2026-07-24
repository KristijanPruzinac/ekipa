import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/repository.dart';
import '../data/supabase_client.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/screen.dart';

class ReflectScreen extends StatefulWidget {
  const ReflectScreen({super.key, required this.meetup, required this.onDone});

  final Meetup meetup;
  final VoidCallback onDone;

  @override
  State<ReflectScreen> createState() => _ReflectScreenState();
}

class _ReflectScreenState extends State<ReflectScreen> {
  final Set<String> _picked = {};
  bool _submitting = false;

  void _toggle(String id) {
    setState(() {
      _picked.contains(id) ? _picked.remove(id) : _picked.add(id);
    });
  }

  Future<void> _done() async {
    setState(() => _submitting = true);
    if (isBackendConfigured) {
      final decisions = {
        for (final a in widget.meetup.attendees) a.id: _picked.contains(a.id),
      };
      try {
        await repository.submitReflection(widget.meetup.id, decisions);
      } catch (_) {
        // Best-effort — nothing useful to show them if this fails silently.
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final attendees = widget.meetup.attendees;

    return Screen(
      backgroundAsset: 'assets/backgrounds/reflect_star.jpg',
      scrim: 0.32,
      footer: Column(
        children: [
          AppButton(label: 'Done', loading: _submitting, onPressed: _done),
          const SizedBox(height: EkipaSpace.sm),
          const AppText(
            "Only shared when it's mutual. If they're not sure, no one ever finds out either way.",
            variant: EkipaTextVariant.caption,
            tone: EkipaTone.faint,
            center: true,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Appear(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('AFTER THE WALK', variant: EkipaTextVariant.label, tone: EkipaTone.moss),
                const SizedBox(height: EkipaSpace.sm),
                const AppText('Who would you be happy to see again?', variant: EkipaTextVariant.title),
                const SizedBox(height: EkipaSpace.sm),
                const AppText(
                  "No rush and no rating — just a quiet nudge about who you'd enjoy running into next time.",
                  tone: EkipaTone.soft,
                ),
              ],
            ),
          ),
          const SizedBox(height: EkipaSpace.xl),
          for (var i = 0; i < attendees.length; i++) ...[
            Appear(
              delay: Duration(milliseconds: 100 + i * 70),
              child: _AttendeeRow(
                attendee: attendees[i],
                selected: _picked.contains(attendees[i].id),
                onToggle: () => _toggle(attendees[i].id),
              ),
            ),
            if (i != attendees.length - 1) const SizedBox(height: EkipaSpace.md),
          ],
        ],
      ),
    );
  }
}

class _AttendeeRow extends StatefulWidget {
  const _AttendeeRow({required this.attendee, required this.selected, required this.onToggle});

  final Attendee attendee;
  final bool selected;
  final VoidCallback onToggle;

  @override
  State<_AttendeeRow> createState() => _AttendeeRowState();
}

class _AttendeeRowState extends State<_AttendeeRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: EkipaMotion.fast,
  );
  late final Animation<double> _heartScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 1),
    TweenSequenceItem(
      tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 2,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = widget.selected;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.all(EkipaSpace.lg),
        decoration: BoxDecoration(
          color: on ? c.moss.withValues(alpha: 0.12) : c.glass,
          borderRadius: BorderRadius.circular(EkipaRadius.lg),
          border: Border.all(color: on ? c.moss.withValues(alpha: 0.45) : c.line, width: 1.3),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.glassStrong, shape: BoxShape.circle),
              child: AppText(
                widget.attendee.firstName[0],
                variant: EkipaTextVariant.bodyStrong,
                tone: EkipaTone.soft,
              ),
            ),
            const SizedBox(width: EkipaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(widget.attendee.firstName, variant: EkipaTextVariant.bodyStrong),
                  AppText(widget.attendee.blurb, variant: EkipaTextVariant.callout, tone: EkipaTone.faint),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _heartScale,
              builder: (context, child) => Transform.scale(scale: _heartScale.value, child: child),
              child: Text(
                on ? '♥' : '♡',
                style: TextStyle(fontSize: 22, color: on ? c.mossGlow : c.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
