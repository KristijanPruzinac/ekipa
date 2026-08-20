import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/state/providers.dart';

/// The ratings, which are mandatory and which the graph runs on.
///
/// **Intention — this is the only fuel the matchmaker has.** Edges form from
/// mutual positive ratings and from nothing else; the respect signal is the
/// only thing keeping hangouts civil. A hangout nobody rates is a hangout that
/// taught the system nothing.
///
/// **What "mandatory" means here, precisely.** An unrated hangout blocks *being
/// matched again*, never using the app (`04_TRUST.md §8`). A turnstile, not a
/// punishment: it clears the moment they rate. Blocking the app is hostile,
/// produces uninstalls, and punishes somebody who only wanted to fix their
/// availability.
///
/// **Anti-satisficing, four mechanisms, none of which try to force sincerity:**
///
/// * **Two seconds minimum per person**, so the screen cannot be cleared by
///   reflex. The delay is *rendered* here and *enforced* by the server — a
///   dwell check in the client is a check a patched client skips, which is why
///   `dwellMs` is sent rather than gated on.
/// * **Randomised order**, which defeats muscle memory across hangouts.
/// * **No bulk control.** There is deliberately no "same for everyone".
/// * **Straight-lining down-weights the rater** rather than rejecting the
///   input. You cannot force sincerity; you can make insincerity cheap to
///   detect and harmless to the graph. Rejecting it would just teach people to
///   add jitter.
///
/// **Nobody ever learns how they were rated** — not the value, not the
/// existence, not an aggregate (invariant 3). There is no screen for it and no
/// gateway method that could feed one.
class RateScreen extends ConsumerStatefulWidget {
  /// Ratings for [hangout].
  const RateScreen({required this.hangout, this.onDone, super.key});

  /// What is being rated.
  final Hangout hangout;

  /// Called once everything is submitted.
  final VoidCallback? onDone;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  final Map<String, Enjoyment> _enjoyment = {};
  final Map<String, bool> _respect = {};
  final Map<String, DateTime> _openedAt = {};
  bool? _easyToFind;
  bool? _goodToMeet;
  bool _busy = false;

  late final List<Member> _others = _shuffled();

  List<Member> _shuffled() {
    // Randomised per hangout, deterministically, so a person who closes the app
    // mid-way returns to the same order. A fresh shuffle on every open would
    // make the anti-muscle-memory device into a source of confusion.
    final others = widget.hangout.members
        .where((member) => !member.isYou)
        .toList();
    final seed = widget.hangout.id.codeUnits.fold<int>(
      7,
      (sum, unit) => (sum * 31 + unit) & 0x7FFFFFFF,
    );
    for (var i = others.length - 1; i > 0; i--) {
      final j = (seed >> (i * 3)) % (i + 1);
      final swap = others[i];
      others[i] = others[j];
      others[j] = swap;
    }
    return others;
  }

  bool get _complete =>
      _others.every(
        (member) =>
            _enjoyment.containsKey(member.id) &&
            _respect.containsKey(member.id),
      ) &&
      _easyToFind != null &&
      _goodToMeet != null;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final now = ref.read(clockProvider).nowUtc();
    try {
      await ref
          .read(gatewayProvider)
          .submitRatings(
            hangoutId: widget.hangout.id,
            answers: [
              for (final member in _others)
                RatingAnswer(
                  subjectId: member.id,
                  enjoyment: _enjoyment[member.id]!,
                  respectful: _respect[member.id]!,
                  dwellMs: now
                      .difference(_openedAt[member.id] ?? now)
                      .inMilliseconds,
                ),
            ],
            venue: VenueVerdict(
              easyToFind: _easyToFind!,
              goodToMeet: _goodToMeet!,
            ),
          );
      ref.invalidate(hangoutsProvider);
      widget.onDone?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EkipaScreen(
    title: 'How was it?',
    lede:
        'Nobody ever finds out what you said — not the answer, not that you '
        'answered. This is the only thing the matching runs on.',
    action: EkipaButton(
      label: _complete ? 'Send' : 'Answer for everyone first',
      busy: _busy,
      onPressed: _complete && !_busy ? _submit : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final member in _others) ...[
          _PersonBlock(
            member: member,
            enjoyment: _enjoyment[member.id],
            respect: _respect[member.id],
            onEnjoyment: (value) => setState(() {
              _openedAt.putIfAbsent(
                member.id,
                () => ref.read(clockProvider).nowUtc(),
              );
              _enjoyment[member.id] = value;
            }),
            onRespect: ({required value}) => setState(() {
              _openedAt.putIfAbsent(
                member.id,
                () => ref.read(clockProvider).nowUtc(),
              );
              _respect[member.id] = value;
            }),
            onReport: () => _report(member),
          ),
          const SizedBox(height: ZarSpace.xl),
        ],

        const Text('And the place?', style: ZarType.heading),
        const SizedBox(height: ZarSpace.xxs),
        Text(
          // This is what makes the venue catalogue self-improving (D11). No
          // star rating anywhere measures "four strangers converging at 17:30",
          // so this is data nobody else has.
          'Two taps. Venues that confuse people stop being used.',
          style: ZarType.body.copyWith(color: ZarColors.inkMuted),
        ),
        const SizedBox(height: ZarSpace.md),
        _YesNo(
          question: 'Was it easy to find?',
          value: _easyToFind,
          onChanged: ({required value}) => setState(() => _easyToFind = value),
        ),
        const SizedBox(height: ZarSpace.sm),
        _YesNo(
          question: 'Did it feel like a good place to meet?',
          value: _goodToMeet,
          onChanged: ({required value}) => setState(() => _goodToMeet = value),
        ),
        const SizedBox(height: ZarSpace.xl),
      ],
    ),
  );

  void _report(Member member) {
    ref
        .read(gatewayProvider)
        .report(
          hangoutId: widget.hangout.id,
          memberId: member.id,
          category: 'reported_from_ratings',
        );
  }
}

class _PersonBlock extends StatelessWidget {
  const _PersonBlock({
    required this.member,
    required this.enjoyment,
    required this.respect,
    required this.onEnjoyment,
    required this.onRespect,
    required this.onReport,
  });

  final Member member;
  final Enjoyment? enjoyment;
  final bool? respect;
  final void Function(Enjoyment value) onEnjoyment;
  final void Function({required bool value}) onRespect;
  final VoidCallback onReport;

  static const List<(Enjoyment, String, String)> _levels = [
    (
      Enjoyment.reallyEnjoyed,
      'Really enjoyed it',
      'For friends this counts the same as the next one. It is what dating '
          'mode uses, later.',
    ),
    (
      Enjoyment.enjoyed,
      'Enjoyed it',
      'Happy to be in a group with them again.',
    ),
    (Enjoyment.noPreference, 'No strong feeling', 'Nothing is recorded.'),
    (
      Enjoyment.ratherNot,
      'Would rather not again',
      'You will never be matched with them again. They are never told.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PersonName(member.name, hero: true),
      const SizedBox(height: ZarSpace.md),
      for (final (value, label, note) in _levels) ...[
        ZarChoice(
          label: label,
          note: note,
          selected: enjoyment == value,
          onPressed: () => onEnjoyment(value),
        ),
        const SizedBox(height: ZarSpace.xs),
      ],
      const SizedBox(height: ZarSpace.sm),
      _YesNo(
        question: 'Were they respectful?',
        value: respect,
        onChanged: onRespect,
      ),
      const SizedBox(height: ZarSpace.xs),
      Align(
        alignment: Alignment.centerLeft,
        child: EkipaButton(
          label: 'Report ${member.name.firstName}',
          tone: EkipaButtonTone.quiet,
          onPressed: onReport,
        ),
      ),
    ],
  );
}

class _YesNo extends StatelessWidget {
  const _YesNo({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final String question;
  final bool? value;
  final void Function({required bool value}) onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(question, style: ZarType.body)),
      const SizedBox(width: ZarSpace.sm),
      _Pill(
        label: 'Yes',
        on: value ?? false,
        onPressed: () => onChanged(value: true),
      ),
      const SizedBox(width: ZarSpace.xs),
      _Pill(
        label: 'No',
        on: value == false,
        onPressed: () => onChanged(value: false),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.on,
    required this.onPressed,
  });

  final String label;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => EkipaButton(
    label: label,
    tone: on ? EkipaButtonTone.primary : EkipaButtonTone.quiet,
    onPressed: onPressed,
  );
}
