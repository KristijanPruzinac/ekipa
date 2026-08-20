/// The app's state graph.
///
/// **Intention — every screen reads from here, and everything here comes from
/// the gateway, the verifier or the clock.** No widget calls the server and no
/// widget reads `DateTime.now()`. The second half is not fussiness: "has this
/// slot passed", "when does the suspension lift", "is the confirmation window
/// still open" are all wall-clock questions, and a screen that asks the real
/// clock is a screen no test can put on either side of a boundary.
///
/// **Where the state machine lives.** In [memberStateProvider] and in each
/// hangout's own `phase` — both of which the server decides and the app
/// renders. Not in a local enum the app advances itself: a client that decided
/// it was `active` because a sign-in succeeded would walk a suspended member
/// into the availability picker, and the refusal would arrive later, from a
/// write, with no explanation attached.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/member_gateway.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/identity/identity_verifier.dart';

// ── Ports, bound at the composition root ─────────────────────────────────────

/// The server-facing port.
///
/// Throws if nothing overrode it. A default that quietly reached the network is
/// how a widget test ends up depending on a project being awake.
final Provider<MemberGateway> gatewayProvider = Provider<MemberGateway>(
  (ref) => throw StateError(
    'gatewayProvider must be overridden at the composition root',
  ),
);

/// How a person proves they are a person.
final Provider<IdentityVerifier> verifierProvider = Provider<IdentityVerifier>(
  (ref) => throw StateError(
    'verifierProvider must be overridden at the composition root',
  ),
);

/// The clock. Same reasoning, same override point.
final Provider<Clock> clockProvider = Provider<Clock>(
  (ref) => throw StateError(
    'clockProvider must be overridden at the composition root',
  ),
);

/// The city geometry the map draws.
///
/// A `Future` because it is an asset read, and `null` when the asset is missing
/// or corrupt — the reveal screen then shows the meeting point without a map
/// rather than showing nothing. A map is context; the address and the standing
/// spot are the answer.
final FutureProvider<Basemap?> basemapProvider = FutureProvider<Basemap?>(
  (ref) => throw StateError(
    'basemapProvider must be overridden at the composition root',
  ),
);

// ── Who is asking, and what they may do ──────────────────────────────────────

/// Where the person stands, per the server.
final FutureProvider<MemberState> memberStateProvider =
    FutureProvider<MemberState>((ref) => ref.watch(gatewayProvider).state());

/// The active sanction, when there is one.
final FutureProvider<SanctionNotice?> sanctionProvider =
    FutureProvider<SanctionNotice?>(
      (ref) => ref.watch(gatewayProvider).sanction(),
    );

/// This person's own row.
final FutureProvider<MemberProfile?> profileProvider =
    FutureProvider<MemberProfile?>(
      (ref) => ref.watch(gatewayProvider).profile(),
    );

// ── Catalogues ───────────────────────────────────────────────────────────────

/// The gender registry (D6).
final FutureProvider<List<GenderOption>> gendersProvider =
    FutureProvider<List<GenderOption>>(
      (ref) => ref.watch(gatewayProvider).genders(),
    );

/// Cities open to signup.
final FutureProvider<List<CityBrief>> citiesProvider =
    FutureProvider<List<CityBrief>>(
      (ref) => ref.watch(gatewayProvider).cities(),
    );

// ── The week ─────────────────────────────────────────────────────────────────

/// The slots this person can still answer, soonest first.
final FutureProvider<List<SlotOption>> slotsProvider =
    FutureProvider<List<SlotOption>>(
      (ref) => ref.watch(gatewayProvider).slots(),
    );

/// The slots grouped by local date, as the **server** last answered.
///
/// **Intention.** The picker's unit is an *evening*, not a slot: a person
/// thinks "I'm around Thursday" and then narrows. Grouping here rather than in
/// the widget means the one place that decides what a day is, is also the place
/// that can be tested without building a screen.
///
/// **It must never read [availabilityProvider], and that is not a style
/// preference.** The picker seeds the draft from this provider's first answer.
/// An earlier version also laid the draft over the days *here*, which closed a
/// loop — seed writes the draft, the draft invalidates this provider, this
/// provider re-emits, the seed fires again — and the screen never settled. It
/// did not crash or warn: `pumpAndSettle` simply spun until it gave up, and the
/// golden run sat producing nothing. The overlay belongs one layer out, in
/// [slotCalendarProvider], where nothing writes back.
final FutureProvider<List<SlotDay>> slotDaysProvider =
    FutureProvider<List<SlotDay>>((ref) async {
      final slots = await ref.watch(slotsProvider.future);
      final byDate = <String, List<SlotOption>>{};
      for (final slot in slots) {
        (byDate[slot.localDate] ??= []).add(slot);
      }
      final dates = byDate.keys.toList()..sort();
      return [
        for (final date in dates)
          SlotDay(
            date: date,
            weekday: byDate[date]!.first.localWeekday,
            slots: List.unmodifiable(
              byDate[date]!..sort((a, b) => a.localTime.compareTo(b.localTime)),
            ),
          ),
      ];
    });

/// The days the calendar draws: the server's, with the unsent draft over them.
///
/// Synchronous, so a tap is on screen in the same frame rather than after a
/// round trip through a `Future`. This is the read side of the split described
/// on [slotDaysProvider]: it depends on the draft, and nothing depends on it,
/// so there is no edge back.
final Provider<AsyncValue<List<SlotDay>>> slotCalendarProvider =
    Provider<AsyncValue<List<SlotDay>>>((ref) {
      final draft = ref.watch(availabilityProvider);
      return ref
          .watch(slotDaysProvider)
          .whenData(
            (days) => [
              for (final day in days)
                SlotDay(
                  date: day.date,
                  weekday: day.weekday,
                  slots: day.slots,
                  held: draft,
                ),
            ],
          );
    });

/// One evening's worth of slots.
@immutable
final class SlotDay {
  /// Describes a day.
  const SlotDay({
    required this.date,
    required this.weekday,
    required this.slots,
    this.held,
  });

  /// `yyyy-mm-dd` in the city.
  final String date;

  /// ISO weekday, 1 = Monday.
  final int weekday;

  /// Its slots, earliest first.
  final List<SlotOption> slots;

  /// The unsent draft, when one is open. When it is, it — not the server's
  /// `chosen` — decides what the calendar shows, so a tap is visible before it
  /// is saved.
  final Set<SlotId>? held;

  /// The calendar date.
  DateTime get day => DateTime.parse(date);

  /// How many of this day's slots are currently taken.
  int get chosenCount => held == null
      ? slots.where((slot) => slot.chosen).length
      : slots.where((slot) => held!.contains(slot.id)).length;

  /// The busiest slot on this day, as the calendar's wash.
  double get density => slots.fold<double>(
    0,
    (best, slot) => slot.density > best ? slot.density : best,
  );
}

// ── What the person has picked but not sent ──────────────────────────────────

/// The availability being edited.
///
/// **Intention — a picker that writes on every tap is a picker that writes
/// forty times.** Each write is an audited row and a possible refusal, and a
/// person changing their mind twice would see two failures for one decision.
/// The taps accumulate here; one button sends the set.
final class AvailabilityDraft extends Notifier<Set<SlotId>?> {
  @override
  Set<SlotId>? build() => null;

  /// Starts from what the server currently holds.
  ///
  /// **Idempotent on purpose.** A draft that already exists is somebody's
  /// half-finished set of taps, and a re-seed would silently discard it. The
  /// guard also means a caller that fires this more than once — a listener on a
  /// provider that re-emits, say — cannot start a write/rebuild cycle.
  void startFrom(Iterable<SlotOption> slots) {
    if (state != null) return;
    state = {
      for (final slot in slots)
        if (slot.chosen) slot.id,
    };
  }

  /// Adds or removes [id].
  void toggle(SlotId id) {
    final current = state;
    if (current == null) return;
    state = {
      for (final held in current)
        if (held != id) held,
      if (!current.contains(id)) id,
    };
  }

  /// Forgets the draft, so the next load re-seeds from the server.
  void clear() => state = null;

  /// Whether [id] is in the set.
  bool holds(SlotId id) => state?.contains(id) ?? false;
}

/// The availability being edited, or `null` before the picker has loaded.
final NotifierProvider<AvailabilityDraft, Set<SlotId>?> availabilityProvider =
    NotifierProvider<AvailabilityDraft, Set<SlotId>?>(AvailabilityDraft.new);

/// Which day the picker has open, or `null` for none.
final NotifierProvider<OpenDay, DateTime?> openDayProvider =
    NotifierProvider<OpenDay, DateTime?>(OpenDay.new);

/// Holds the calendar's open day.
final class OpenDay extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Opens [day], or closes it if it was already open.
  void toggle(DateTime day) => state = state == day ? null : day;
}

// ── The hangouts ─────────────────────────────────────────────────────────────

/// Everything this person is in that has not closed.
final FutureProvider<List<Hangout>> hangoutsProvider =
    FutureProvider<List<Hangout>>(
      (ref) => ref.watch(gatewayProvider).hangouts(),
    );

/// The one hangout that wants something from the person right now, if any.
///
/// **Intention — the home screen has one job: say what to do next.** A list of
/// hangouts is a list of things to read; a single card is an instruction. The
/// order below is the order of urgency, not of time: an unanswered confirmation
/// outranks a revealed hangout that starts sooner, because the confirmation has
/// a deadline and somebody else's evening depends on it.
final Provider<AsyncValue<Hangout?>> nextHangoutProvider =
    Provider<AsyncValue<Hangout?>>((ref) {
      const urgency = [
        HangoutPhase.live,
        HangoutPhase.rating,
        HangoutPhase.confirming,
        HangoutPhase.revealed,
        HangoutPhase.backfilling,
        HangoutPhase.locked,
        HangoutPhase.proposed,
      ];
      return ref.watch(hangoutsProvider).whenData((hangouts) {
        final open = [
          for (final phase in urgency)
            ...hangouts.where((hangout) => hangout.phase == phase),
        ];
        return open.isEmpty ? null : open.first;
      });
    });

/// The activity's cards for a hangout id.
///
/// Left unannotated: Riverpod 3 does not export the family types, so there is
/// no name to write here. `final` plus the factory's own generics is the whole
/// of what can be said.
// ignore: specify_nonobvious_property_types
final activityCardsProvider = FutureProvider.family<List<ActivityCard>, String>(
  (ref, hangoutId) => ref.watch(gatewayProvider).activityCards(hangoutId),
);

// ── Onboarding ───────────────────────────────────────────────────────────────

/// What onboarding has collected so far.
///
/// **Intention — one value, carried across the steps, sent once.** The
/// alternative is a write per screen, which means as many ways to end up with
/// half a member: a row with a name and no gender is a person the matcher
/// silently never places, and nothing looks broken.
///
/// **There is no city here.** Osijek is locked, `people.city_id` is not
/// client-settable by design, and the server derives the city from the anchor.
/// **There is no travel radius either** — corrected 2026-08-20: match anywhere
/// in town, ranked by closest distance.
@immutable
final class Onboarding {
  /// Describes a partially answered signup.
  const Onboarding({
    this.firstName = '',
    this.lastInitial = '',
    this.genderCode,
    this.anchorLatitude,
    this.anchorLongitude,
    this.equipment = const [],
    this.declinedAnchor = false,
  });

  /// From the verifier, not typed twice.
  final String firstName;

  /// From the verifier.
  final String lastInitial;

  /// Registry code, once chosen.
  final String? genderCode;

  /// Where they set out from. Snapped by the server, never here.
  final double? anchorLatitude;

  /// The other half of the anchor.
  final double? anchorLongitude;

  /// What they can bring.
  final List<String> equipment;

  /// Whether they were asked for a location and said no.
  ///
  /// A separate flag rather than a sentinel coordinate. "Declined" and "not
  /// asked yet" are different states, and encoding the first as a NaN would
  /// send a coordinate to the server that reads as a real place.
  final bool declinedAnchor;

  /// Whether every required answer is in.
  ///
  /// The anchor is deliberately not required: somebody who declines location
  /// can still be matched, just less well, and a signup that dead-ends on a
  /// permission dialog loses a person over a preference.
  bool get isComplete =>
      firstName.isNotEmpty && lastInitial.isNotEmpty && genderCode != null;

  /// A copy with the named fields replaced.
  Onboarding copyWith({
    String? firstName,
    String? lastInitial,
    String? genderCode,
    double? anchorLatitude,
    double? anchorLongitude,
    List<String>? equipment,
    bool? declinedAnchor,
  }) => Onboarding(
    firstName: firstName ?? this.firstName,
    lastInitial: lastInitial ?? this.lastInitial,
    genderCode: genderCode ?? this.genderCode,
    anchorLatitude: anchorLatitude ?? this.anchorLatitude,
    anchorLongitude: anchorLongitude ?? this.anchorLongitude,
    equipment: equipment ?? this.equipment,
    declinedAnchor: declinedAnchor ?? this.declinedAnchor,
  );
}

/// Carries the answers between onboarding screens.
final class OnboardingController extends Notifier<Onboarding> {
  @override
  Onboarding build() => const Onboarding();

  /// Seeds the name from a completed verification.
  void beginWith(VerifiedIdentity identity) {
    state = state.copyWith(
      firstName: identity.firstName,
      lastInitial: identity.lastInitial,
    );
  }

  /// Records the chosen gender.
  void setGender(String code) => state = state.copyWith(genderCode: code);

  /// Records where they set out from.
  void setAnchor(double latitude, double longitude) => state = Onboarding(
    firstName: state.firstName,
    lastInitial: state.lastInitial,
    genderCode: state.genderCode,
    anchorLatitude: latitude,
    anchorLongitude: longitude,
    equipment: state.equipment,
  );

  /// Records that they were asked and said no.
  void declineAnchor() => state = Onboarding(
    firstName: state.firstName,
    lastInitial: state.lastInitial,
    genderCode: state.genderCode,
    equipment: state.equipment,
    declinedAnchor: true,
  );

  /// Records what they can bring.
  void setEquipment(List<String> codes) =>
      state = state.copyWith(equipment: codes);
}

/// The signup in progress.
final NotifierProvider<OnboardingController, Onboarding> onboardingProvider =
    NotifierProvider<OnboardingController, Onboarding>(
      OnboardingController.new,
    );
