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
  // Only holds people the user has actually answered for. Leaving someone
  // unanswered is a valid, pressure-free choice — it reads as "no preference"
  // and writes nothing.
  final Map<String, Sentiment> _feelings = {};
  bool _submitting = false;

  void _choose(String id, Sentiment s) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_feelings[id] == s) {
        _feelings.remove(id); // tapping the chosen one again clears it
      } else {
        _feelings[id] = s;
      }
    });
  }

  Future<void> _done() async {
    setState(() => _submitting = true);
    if (isBackendConfigured) {
      try {
        await repository.submitReflection(widget.meetup.id, _feelings);
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
      ambient: true,
      footer: Column(
        children: [
          AppButton(label: 'Done', loading: _submitting, onPressed: _done),
          const SizedBox(height: EkipaSpace.sm),
          const AppText(
            "Only used to shape who you meet next — and only when it's mutual. "
            "No one is ever told how you answered.",
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
                const AppText('AFTER THE MEETUP', variant: EkipaTextVariant.label, tone: EkipaTone.moss),
                const SizedBox(height: EkipaSpace.sm),
                const AppText('How did it feel?', variant: EkipaTextVariant.title),
                const SizedBox(height: EkipaSpace.sm),
                const AppText(
                  "No rush, no rating. Just a quiet sense of who you'd be glad to "
                  "run into again — and who you'd rather not.",
                  tone: EkipaTone.soft,
                ),
              ],
            ),
          ),
          const SizedBox(height: EkipaSpace.xl),
          for (var i = 0; i < attendees.length; i++) ...[
            Appear(
              delay: Duration(milliseconds: 100 + i * 70),
              child: _AttendeeReflection(
                attendee: attendees[i],
                selected: _feelings[attendees[i].id],
                onChoose: (s) => _choose(attendees[i].id, s),
              ),
            ),
            if (i != attendees.length - 1) const SizedBox(height: EkipaSpace.md),
          ],
        ],
      ),
    );
  }
}

/// One person with the four-level feeling selector beneath their name.
class _AttendeeReflection extends StatelessWidget {
  const _AttendeeReflection({
    required this.attendee,
    required this.selected,
    required this.onChoose,
  });

  final Attendee attendee;
  final Sentiment? selected;
  final ValueChanged<Sentiment> onChoose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(EkipaSpace.lg),
      decoration: BoxDecoration(
        color: c.glass,
        borderRadius: BorderRadius.circular(EkipaRadius.lg),
        border: Border.all(color: c.line, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.glassStrong, shape: BoxShape.circle),
                child: AppText(attendee.firstName[0],
                    variant: EkipaTextVariant.bodyStrong, tone: EkipaTone.soft),
              ),
              const SizedBox(width: EkipaSpace.md),
              AppText(attendee.firstName, variant: EkipaTextVariant.bodyStrong),
            ],
          ),
          const SizedBox(height: EkipaSpace.md),
          Wrap(
            spacing: EkipaSpace.sm,
            runSpacing: EkipaSpace.sm,
            children: [
              for (final opt in _sentimentOptions)
                _SentimentChip(
                  option: opt,
                  active: selected == opt.value,
                  onTap: () => onChoose(opt.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentimentOption {
  const _SentimentOption(this.value, this.label);
  final Sentiment value;
  final String label;
}

const _sentimentOptions = [
  _SentimentOption(Sentiment.reallyEnjoyed, 'Really enjoyed'),
  _SentimentOption(Sentiment.enjoyed, 'Enjoyed'),
  _SentimentOption(Sentiment.noPreference, 'No preference'),
  _SentimentOption(Sentiment.ratherNot, 'Rather not'),
];

class _SentimentChip extends StatelessWidget {
  const _SentimentChip({
    required this.option,
    required this.active,
    required this.onTap,
  });

  final _SentimentOption option;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Warmth scales with the feeling; "rather not" stays deliberately muted so
    // choosing it never feels like an accusation. Nothing about it alarms.
    final (Color border, Color fill, Color text) = switch (option.value) {
      Sentiment.reallyEnjoyed => (
          c.moss.withValues(alpha: 0.65),
          c.moss.withValues(alpha: 0.20),
          c.mossGlow,
        ),
      Sentiment.enjoyed => (
          c.moss.withValues(alpha: 0.45),
          c.moss.withValues(alpha: 0.12),
          c.moss,
        ),
      Sentiment.noPreference => (c.line, c.glassStrong, c.inkSoft),
      Sentiment.ratherNot => (c.line, c.glassStrong, c.inkSoft),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: EkipaMotion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
            horizontal: EkipaSpace.md, vertical: EkipaSpace.sm),
        decoration: BoxDecoration(
          color: active ? fill : Colors.transparent,
          borderRadius: BorderRadius.circular(EkipaRadius.pill),
          border: Border.all(
            color: active ? border : c.line,
            width: active ? 1.4 : 1.0,
          ),
        ),
        child: AppText(
          option.label,
          variant: EkipaTextVariant.calloutStrong,
          style: TextStyle(color: active ? text : c.inkFaint),
        ),
      ),
    );
  }
}
