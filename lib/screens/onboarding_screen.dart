import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/profile_status.dart';
import '../data/repository.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text.dart';
import '../widgets/appear.dart';
import '../widgets/screen.dart';

/// The one-time logistics pass, after the phone code. Deliberately *only*
/// logistics — when you're free, what part of town, how many people, what
/// you'd actually do. Nothing to write about yourself, no personality to
/// perform. That's the line the zero-onboarding principle draws: the app
/// never asks you to sell yourself, only what it needs to place you well.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstName = TextEditingController();
  final _city = TextEditingController(text: 'Osijek');

  String? _gender;
  bool _sameGenderOnly = false;
  int _groupSize = 3;
  final Set<String> _activities = {};
  final Set<String> _availability = {};

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _city.dispose();
    super.dispose();
  }

  bool get _ready =>
      _firstName.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _gender != null &&
      _activities.isNotEmpty &&
      _availability.isNotEmpty;

  Future<void> _save() async {
    if (!_ready) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repository.saveProfile(
        firstName: _firstName.text.trim(),
        city: _city.text.trim(),
        gender: _gender,
        sameGenderOnly: _sameGenderOnly,
        groupSizePref: _groupSize,
        activities: _activities.toList(),
        availability: _availability.toList(),
      );
      profileStatus.markComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "That didn't save — check your connection and try again.";
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      // A long scrolling form needs an even, dark ground for legibility — the
      // night sky, not the bright dawn the short auth screen can afford.
      backgroundAsset: 'assets/backgrounds/home_night.jpg',
      scrim: 0.35,
      footer: Column(
        children: [
          if (_error != null) ...[
            AppText(_error!, tone: EkipaTone.danger, center: true),
            const SizedBox(height: EkipaSpace.sm),
          ],
          AppButton(
            label: "That's everything",
            loading: _saving,
            disabled: !_ready,
            onPressed: _save,
          ),
          const SizedBox(height: EkipaSpace.sm),
          const AppText(
            'Takes about a minute. You can change any of it later.',
            variant: EkipaTextVariant.caption,
            tone: EkipaTone.faint,
            center: true,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Appear(
            child: AppText('A few quick things', variant: EkipaTextVariant.title),
          ),
          const SizedBox(height: EkipaSpace.sm),
          const Appear(
            delay: Duration(milliseconds: 70),
            child: AppText(
              'Only what we need to place you with the right small group nearby. '
              'Nothing about this is a profile.',
              tone: EkipaTone.soft,
            ),
          ),
          const SizedBox(height: EkipaSpace.xl),

          _Field(
            label: 'Your first name',
            child: _TextInput(controller: _firstName, hint: 'First name', onChanged: _refresh),
          ),
          const SizedBox(height: EkipaSpace.lg),
          _Field(
            label: 'Your city',
            child: _TextInput(controller: _city, hint: 'City', onChanged: _refresh),
          ),
          const SizedBox(height: EkipaSpace.lg),

          _Field(
            label: 'You are',
            child: _PillGroup(
              options: _genders,
              isSelected: (v) => _gender == v,
              onTap: (v) => setState(() => _gender = v),
            ),
          ),
          const SizedBox(height: EkipaSpace.md),
          _Toggle(
            value: _sameGenderOnly,
            onChanged: (v) => setState(() => _sameGenderOnly = v),
            label: 'Only group me with the same gender',
          ),
          const SizedBox(height: EkipaSpace.lg),

          _Field(
            label: 'Group size you prefer',
            child: _PillGroup(
              options: const [
                _Option('2', 'Just one other'),
                _Option('3', 'Two others'),
                _Option('4', 'A small group'),
              ],
              isSelected: (v) => _groupSize.toString() == v,
              onTap: (v) => setState(() => _groupSize = int.parse(v)),
            ),
          ),
          const SizedBox(height: EkipaSpace.lg),

          _Field(
            label: 'When you tend to be free',
            child: _PillGroup(
              options: _availabilityOptions,
              isSelected: _availability.contains,
              onTap: (v) => setState(() => _toggle(_availability, v)),
            ),
          ),
          const SizedBox(height: EkipaSpace.lg),

          _Field(
            label: "Things you'd actually show up for",
            child: _PillGroup(
              options: _activityOptions,
              isSelected: _activities.contains,
              onTap: (v) => setState(() => _toggle(_activities, v)),
            ),
          ),
          const SizedBox(height: EkipaSpace.md),
        ],
      ),
    );
  }

  void _refresh(String _) => setState(() {});

  void _toggle(Set<String> set, String v) {
    HapticFeedback.selectionClick();
    set.contains(v) ? set.remove(v) : set.add(v);
  }
}

const _genders = [
  _Option('woman', 'Woman'),
  _Option('man', 'Man'),
  _Option('nonbinary', 'Non-binary'),
];

const _availabilityOptions = [
  _Option('weekday_morning', 'Weekday mornings'),
  _Option('weekday_evening', 'Weekday evenings'),
  _Option('weekend_day', 'Weekend days'),
  _Option('weekend_evening', 'Weekend evenings'),
];

const _activityOptions = [
  _Option('walk', 'Walking'),
  _Option('coffee_quiet', 'Quiet coffee'),
  _Option('boardgames', 'Board games'),
  _Option('hike', 'Hiking'),
  _Option('reading', 'Reading'),
  _Option('photography', 'Photo walks'),
  _Option('bouldering', 'Bouldering'),
  _Option('cooking', 'Cooking'),
  _Option('cinema', 'Cinema'),
  _Option('cowork_hobby', 'Hobby co-work'),
];

class _Option {
  const _Option(this.value, this.label);
  final String value;
  final String label;
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label.toUpperCase(), variant: EkipaTextVariant.label, tone: EkipaTone.moss),
        const SizedBox(height: EkipaSpace.sm),
        child,
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: c.ink, fontSize: 17),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.inkFaint),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}

class _PillGroup extends StatelessWidget {
  const _PillGroup({required this.options, required this.isSelected, required this.onTap});

  final List<_Option> options;
  final bool Function(String value) isSelected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: EkipaSpace.sm,
      runSpacing: EkipaSpace.sm,
      children: [
        for (final o in options)
          _Pill(label: o.label, active: isSelected(o.value), onTap: () => onTap(o.value)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: EkipaMotion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: EkipaSpace.md, vertical: EkipaSpace.sm),
        decoration: BoxDecoration(
          color: active ? c.moss.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(EkipaRadius.pill),
          border: Border.all(
            color: active ? c.moss.withValues(alpha: 0.55) : c.line,
            width: active ? 1.4 : 1.0,
          ),
        ),
        child: AppText(
          label,
          variant: EkipaTextVariant.calloutStrong,
          style: TextStyle(color: active ? c.mossGlow : c.inkSoft),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Row(
        children: [
          Expanded(
            child: AppText(label, variant: EkipaTextVariant.callout, tone: EkipaTone.soft),
          ),
          const SizedBox(width: EkipaSpace.md),
          AnimatedContainer(
            duration: EkipaMotion.fast,
            width: 46,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? c.moss.withValues(alpha: 0.5) : c.glassStrong,
              borderRadius: BorderRadius.circular(EkipaRadius.pill),
              border: Border.all(color: value ? c.moss.withValues(alpha: 0.6) : c.line),
            ),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? c.mossGlow : c.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
