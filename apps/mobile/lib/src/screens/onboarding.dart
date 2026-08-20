import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:mobile/src/widgets/async_block.dart';

/// Which gender, from the registry.
///
/// **Intention — this is the one profile answer the matching rule needs**, and
/// it is asked once because it cannot be changed afterwards: a person who could
/// change it on the morning of a run could defeat the composition invariant.
///
/// **The rule is never named on this screen.** The invariant is *no person is
/// ever the only one of their gender in a group* — and a screen that explained
/// that would turn a profile field into a lever people optimise. What it says
/// instead is true and useless to game: we use it to build the group.
class GenderStep extends ConsumerWidget {
  /// The gender step.
  const GenderStep({required this.onNext, super.key});

  /// Called once an answer is chosen.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(gendersProvider);
    final draft = ref.watch(onboardingProvider);

    return EkipaScreen(
      title: 'Which of these are you?',
      lede:
          'We use it to build the group, and for nothing else. It is never '
          'shown to anybody.',
      action: EkipaButton(
        label: 'Next',
        onPressed: draft.genderCode == null ? null : onNext,
      ),
      child: AsyncBlock<List<GenderOption>>(
        value: options,
        builder: (loaded) => Column(
          children: [
            for (final option in loaded) ...[
              ZarChoice(
                label: option.label,
                selected: draft.genderCode == option.code,
                onPressed: () => ref
                    .read(onboardingProvider.notifier)
                    .setGender(option.code),
              ),
              const SizedBox(height: ZarSpace.xs),
            ],
            const SizedBox(height: ZarSpace.md),
            Text(
              'This is a registry, not a fixed list of three — the rule that '
              'builds groups never names a particular value, so adding one '
              'later changes a table and nothing else.',
              style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where you set out from.
///
/// **Intention — the anchor is the distance signal, and it is the whole of
/// it.** There is deliberately **no "how far will you go" question**: corrected
/// 2026-08-20, the requirement is *match anywhere in town, ranked by closest
/// distance*. An earlier draft added a travel-radius control that no line of
/// the Bible asks for, and every extra question before a first hangout is a
/// place the signup dissolves.
///
/// **Location permission is optional and never a gate** (`05_PLACES.md §2`). A
/// dropped pin is as good as a GPS fix for "roughly where do you start from",
/// and it is cheaper in trust. The denial path is first-class, not a fallback.
///
/// **What the server does with it, stated on the screen:** snaps it to a ~500 m
/// grid before storing. Saying so is not a legal formality — it is the
/// difference between a person believing the app keeps their address and
/// knowing it does not.
class NeighbourhoodStep extends ConsumerWidget {
  /// The anchor step.
  const NeighbourhoodStep({
    required this.onFinish,
    required this.busy,
    this.failure,
    super.key,
  });

  /// Called when the person is done.
  final VoidCallback onFinish;

  /// Whether the profile is being written.
  final bool busy;

  /// What the server said, if it refused.
  final String? failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final cities = ref.watch(citiesProvider).value ?? const <CityBrief>[];
    final basemap = ref.watch(basemapProvider).value;
    final centre = cities.isEmpty ? null : cities.first.centre;
    final placed = draft.anchorLatitude != null;

    return EkipaScreen(
      title: 'Where do you usually set out from?',
      lede:
          'Roughly. It is how we put you with people who are not across town '
          '— nothing else, and nobody ever sees it.',
      action: EkipaButton(
        label: placed ? 'Done' : 'Skip this',
        busy: busy,
        onPressed: busy ? null : onFinish,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (basemap != null && centre != null)
            MapSurface(
              basemap: basemap,
              meetingPoint: draft.anchorLatitude == null
                  ? centre
                  : _at(draft.anchorLatitude!, draft.anchorLongitude!),
              zoom: 2.2,
              height: 240,
            ),
          const SizedBox(height: ZarSpace.md),

          ZarChoice(
            label: 'Use where I am now',
            note: 'One reading, right now. Never in the background, ever.',
            selected: placed,
            onPressed: () => ref
                .read(onboardingProvider.notifier)
                // A real fix comes from the platform layer; the rehearsal build
                // uses the city centre so the screen can be built and looked at
                // without a permission dialog.
                .setAnchor(
                  centre?.latitude ?? 45.5550,
                  centre?.longitude ?? 18.6955,
                ),
          ),
          const SizedBox(height: ZarSpace.xs),
          ZarChoice(
            label: 'I would rather not',
            note:
                'Completely fine. You still get matched — just a little less '
                'well, because we cannot tell who is near you.',
            selected: draft.declinedAnchor,
            onPressed: () =>
                ref.read(onboardingProvider.notifier).declineAnchor(),
          ),

          const SizedBox(height: ZarSpace.lg),
          EkipaCard(
            tone: EkipaCardTone.quiet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What we do with it', style: ZarType.bodyStrong),
                const SizedBox(height: ZarSpace.xs),
                Text(
                  'It is snapped to a 500-metre grid before it is stored, so '
                  'what the database holds is a neighbourhood, not an address. '
                  'It is never shown to another person — not on the map, not '
                  'at the reveal, not ever.',
                  style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                ),
              ],
            ),
          ),

          if (failure != null) ...[
            const SizedBox(height: ZarSpace.md),
            Text(failure!, style: ZarType.body.copyWith(color: ZarColors.rose)),
          ],
        ],
      ),
    );
  }
}

/// What you can bring.
///
/// **Intention — this is a matchmaker constraint wearing a friendly hat.** A
/// `CARDS` hangout needs two people carrying a deck, because one can dip
/// (the transcript's own reasoning, and its number). Asking here means the
/// assembler can guarantee it rather than hope for it.
class EquipmentStep extends ConsumerWidget {
  /// The equipment step.
  const EquipmentStep({required this.onNext, super.key});

  /// Called when the person moves on.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final carries = draft.equipment.contains('deck_of_cards');
    return EkipaScreen(
      title: 'Could you bring a deck of cards?',
      lede:
          'Some hangouts are card games. They need two people carrying a deck '
          '— one person can always end up not coming.',
      action: EkipaButton(label: 'Next', onPressed: onNext),
      child: Column(
        children: [
          ZarChoice(
            label: 'Yes, I have one',
            note: 'You will be asked to confirm before each one.',
            selected: carries,
            onPressed: () => ref.read(onboardingProvider.notifier).setEquipment(
              const ['deck_of_cards'],
            ),
          ),
          const SizedBox(height: ZarSpace.xs),
          ZarChoice(
            label: 'No',
            note: 'Then you get the talking ones, which is most of them.',
            selected: !carries,
            onPressed: () =>
                ref.read(onboardingProvider.notifier).setEquipment(const []),
          ),
        ],
      ),
    );
  }
}

/// A `GeoPoint` from two doubles, for the anchor preview.
///
/// A local helper rather than a positional constructor on `GeoPoint`: the named
/// arguments there are deliberate, because a bare `(45.5, 18.7)` at a call site
/// is a latitude/longitude swap waiting to happen.
GeoPoint _at(double latitude, double longitude) =>
    GeoPoint(latitude: latitude, longitude: longitude);
