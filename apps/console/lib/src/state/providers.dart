/// The console's state graph.
///
/// **Intention — everything the screens read comes from here, and everything
/// here comes from the gateway or the clock.** No widget calls an RPC, and no
/// widget reads `DateTime.now()`. The second half matters more than it looks:
/// three separate rules in this app are "is this in the past" questions —
/// whether a version is live, whether a slot is ahead, whether an in-flight
/// hangout is still exposed — and a screen that asks the wall clock directly is
/// a screen no test can put on either side of a boundary.
///
/// **Why there is not a `family` in sight.** Riverpod 3 does not export the
/// family types, so a parameterised provider cannot be given a type annotation
/// — but the better reason is that the two parameters this console would have
/// used, "which version" and "which city", are *selections*, not arguments.
/// Modelling them as state and deriving downward means one place decides what
/// is selected and every dependent view follows, instead of four screens each
/// passing what they believe the answer to be.
library;

import 'package:console/src/catalogue.dart';
import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/data/records.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Ports, overridden at the composition root ────────────────────────────────

/// The server-facing port. Overridden at the composition root, and in tests.
///
/// Throws if nothing overrode it, rather than defaulting to a real client: a
/// default that silently reaches the network is how a widget test ends up
/// depending on a project being awake.
final Provider<ConsoleGateway> gatewayProvider = Provider<ConsoleGateway>(
  (ref) => throw StateError(
    'gatewayProvider must be overridden at the composition root',
  ),
);

/// The clock. Same reasoning as [gatewayProvider], and the same override point.
final Provider<Clock> clockProvider = Provider<Clock>(
  (ref) => throw StateError(
    'clockProvider must be overridden at the composition root',
  ),
);

/// Every key this binary may edit.
final Provider<ConfigCatalogue> catalogueProvider = Provider<ConfigCatalogue>(
  (ref) => buildConsoleCatalogue(),
);

// ── Who is asking ────────────────────────────────────────────────────────────

/// The caller's console role, as the database sees it.
///
/// This is the app's single source of truth for what the operator may do, and
/// it is a *server* answer. Nothing below infers a role from a sign-in, from a
/// stored preference, or from the fact that a screen managed to load — rule 6:
/// if the UI hides it, the server must also refuse it, and the way to keep
/// those two in step is to have the UI hide it *because* the server said so.
final FutureProvider<String?> roleProvider = FutureProvider<String?>(
  (ref) => ref.watch(gatewayProvider).role(),
);

/// Whether the caller is at least [role], on the same ladder as the database.
///
/// Mirrors `admin_at_least` deliberately, including its ordering. A screen that
/// invented its own ladder would be a second opinion, and the server's is the
/// one that counts.
bool atLeast(String? held, String role) {
  const ladder = ['viewer', 'operator', 'owner'];
  final have = ladder.indexOf(held ?? '');
  final need = ladder.indexOf(role);
  return have >= 0 && need >= 0 && have >= need;
}

// ── Selections ───────────────────────────────────────────────────────────────

/// Holds one nullable selection.
///
/// Riverpod 3 moved `StateProvider` into `legacy/` and stopped exporting it, so
/// a selection is a short notifier now. Kept generic rather than written twice,
/// because the second copy is where the two would drift.
final class Selection<T> extends Notifier<T?> {
  @override
  T? build() => null;

  /// The chosen value, or `null` for "whatever the default is".
  T? get selected => state;

  set selected(T? value) => state = value;
}

/// The version being read or edited. `null` means the newest one.
///
/// Storing the selection rather than the resolved record keeps it stable across
/// a refresh: a list that reloads does not silently move the operator to a
/// different version than the one they were reading.
final NotifierProvider<Selection<ConfigVersionId>, ConfigVersionId?>
selectedVersionProvider =
    NotifierProvider<Selection<ConfigVersionId>, ConfigVersionId?>(
      Selection<ConfigVersionId>.new,
    );

/// The city being looked at. `null` means the first active one.
final NotifierProvider<Selection<CityId>, CityId?> selectedCityProvider =
    NotifierProvider<Selection<CityId>, CityId?>(Selection<CityId>.new);

// ── Configuration ────────────────────────────────────────────────────────────

/// The stored config versions, newest effective-from first.
final FutureProvider<List<ConfigVersionRecord>> configVersionsProvider =
    FutureProvider<List<ConfigVersionRecord>>(
      (ref) => ref.watch(gatewayProvider).configVersions(limit: 50),
    );

/// The version the console is currently showing, or `null` if there are none.
final FutureProvider<ConfigVersionRecord?> activeVersionProvider =
    FutureProvider<ConfigVersionRecord?>((ref) async {
      final versions = await ref.watch(configVersionsProvider.future);
      if (versions.isEmpty) return null;
      final chosen = ref.watch(selectedVersionProvider);
      if (chosen == null) return versions.first;
      for (final version in versions) {
        if (version.id.value == chosen.value) return version;
      }
      // The selection points at a version this list no longer carries — it was
      // published from another tab, or scrolled off the limit. Falling back to
      // the newest is better than an empty screen with no way out of it.
      return versions.first;
    });

/// Every value the active version carries, at every layer.
final FutureProvider<List<ConfigValueRow>> configValuesProvider =
    FutureProvider<List<ConfigValueRow>>((ref) async {
      final version = await ref.watch(activeVersionProvider.future);
      if (version == null) return const [];
      return ref.watch(gatewayProvider).configValues(version.id);
    });

// ── Cities and the week ──────────────────────────────────────────────────────

/// Cities, including inactive ones.
final FutureProvider<List<CityRecord>> citiesProvider =
    FutureProvider<List<CityRecord>>(
      (ref) => ref.watch(gatewayProvider).cities(),
    );

/// The city the schedule screen is showing.
final FutureProvider<CityRecord?> activeCityProvider =
    FutureProvider<CityRecord?>((ref) async {
      final cities = await ref.watch(citiesProvider.future);
      if (cities.isEmpty) return null;
      final chosen = ref.watch(selectedCityProvider);
      if (chosen == null) return cities.first;
      for (final city in cities) {
        if (city.id.value == chosen.value) return city;
      }
      return cities.first;
    });

/// The configuration as it resolves *for the selected city*.
///
/// **Intention.** This is the provider the config screen reads, and the reason
/// the whole scope ladder exists. `ConfigResolver.resolve` returns both the
/// values and the layer each one came from, so a screen can answer "why is this
/// 3?" with "because Osijek overrides it" rather than just showing a 3. A
/// console that shows only the resolved number is a console where a global
/// change appears to do nothing and nobody can say why.
final FutureProvider<ConfigResolution?> resolvedConfigProvider =
    FutureProvider<ConfigResolution?>((ref) async {
      final version = await ref.watch(activeVersionProvider.future);
      if (version == null) return null;
      final rows = await ref.watch(configValuesProvider.future);
      final city = await ref.watch(activeCityProvider.future);
      return ConfigResolver.resolve(
        versionId: version.id,
        rows: rows,
        target: city == null
            ? const ConfigTarget.everywhere()
            : ConfigTarget(cityId: city.id, countryCode: city.countryCode),
      );
    });

/// The slot schedule the active configuration describes.
///
/// An error rather than an exception when the keys are malformed: a schedule
/// nobody can parse is an operator-facing problem, and the screen prints the
/// message.
final FutureProvider<Result<SlotSchedule, String>?> scheduleProvider =
    FutureProvider<Result<SlotSchedule, String>?>((ref) async {
      final resolved = await ref.watch(resolvedConfigProvider.future);
      if (resolved == null) return null;
      return SlotSchedule.fromSnapshot(resolved.snapshot);
    });

/// Slots already materialised for the active city, over the configured horizon.
final FutureProvider<List<SlotRecord>> slotsProvider =
    FutureProvider<List<SlotRecord>>((ref) async {
      final city = await ref.watch(activeCityProvider.future);
      if (city == null) return const [];
      final resolved = await ref.watch(resolvedConfigProvider.future);
      final weeks = resolved == null
          ? ScheduleKeys.horizonWeeks.defaultValue
          : resolved.snapshot.get(ScheduleKeys.horizonWeeks);
      final now = ref.watch(clockProvider).nowUtc();
      return ref
          .watch(gatewayProvider)
          .slots(
            cityId: city.id,
            from: now,
            to: now.add(Duration(days: 7 * weeks)),
          );
    });

// ── Consequence ──────────────────────────────────────────────────────────────

/// What a rule change could still reach.
final FutureProvider<List<InFlightObject>> inFlightProvider =
    FutureProvider<List<InFlightObject>>(
      (ref) => ref.watch(gatewayProvider).inFlight(),
    );

/// The audit trail.
final FutureProvider<List<AuditRecord>> auditProvider =
    FutureProvider<List<AuditRecord>>(
      (ref) => ref.watch(gatewayProvider).audit(limit: 100),
    );

// ── The draft under edit ─────────────────────────────────────────────────────

/// The edits an operator has made but not published.
///
/// **Intention — the draft is a plain value, and the notifier only replaces
/// it.** All the interesting behaviour (what changed, what is broken, whether
/// it may be published) lives on [ConfigDraft] in `ekipa_core`, where it is
/// pure and covered by tests that no widget has to be built to run. This class
/// is a box. That is the whole point of it.
final class DraftController extends Notifier<ConfigDraft?> {
  @override
  ConfigDraft? build() => null;

  /// Begins editing on top of a published version.
  void start({
    required ConfigVersionId baseVersionId,
    required List<ConfigValueRow> baseRows,
    required DateTime effectiveFrom,
  }) {
    state = ConfigDraft(
      baseVersionId: baseVersionId,
      baseRows: baseRows,
      note: '',
      effectiveFrom: effectiveFrom,
      edits: const [],
    );
  }

  /// Abandons the draft. Nothing was written, so nothing is undone.
  void discard() => state = null;

  /// Sets [key] at [scope] to [value], replacing any earlier edit at the same
  /// coordinate.
  ///
  /// Replacing rather than appending keeps the diff honest: two edits to one
  /// key are one change, and a list that grew would show the operator a history
  /// of their own typing instead of what the version will contain.
  void edit({
    required String key,
    required ConfigScope scope,
    required Object? value,
  }) {
    final current = state;
    if (current == null) return;
    state = _copy(
      current,
      edits: [
        for (final edit in current.edits)
          if (!(edit.key == key && edit.scope == scope)) edit,
        ConfigEdit(key: key, scope: scope, value: value),
      ],
    );
  }

  /// Removes an edit, returning that coordinate to whatever the base held.
  void revert({required String key, required ConfigScope scope}) {
    final current = state;
    if (current == null) return;
    state = _copy(
      current,
      edits: [
        for (final edit in current.edits)
          if (!(edit.key == key && edit.scope == scope)) edit,
      ],
    );
  }

  /// Sets the note that says what this version is.
  void setNote(String note) {
    final current = state;
    if (current == null) return;
    state = _copy(current, note: note);
  }

  /// Sets when the version starts to apply.
  void setEffectiveFrom(DateTime when) {
    final current = state;
    if (current == null) return;
    state = _copy(current, effectiveFrom: when);
  }

  static ConfigDraft _copy(
    ConfigDraft draft, {
    String? note,
    DateTime? effectiveFrom,
    List<ConfigEdit>? edits,
  }) => ConfigDraft(
    baseVersionId: draft.baseVersionId,
    baseRows: draft.baseRows,
    note: note ?? draft.note,
    effectiveFrom: effectiveFrom ?? draft.effectiveFrom,
    edits: edits ?? draft.edits,
  );
}

/// The draft under edit, or `null` when nothing is being edited.
final NotifierProvider<DraftController, ConfigDraft?> draftProvider =
    NotifierProvider<DraftController, ConfigDraft?>(DraftController.new);

/// What the draft would break, if anything.
///
/// Recomputed on every keystroke rather than on submit. `12_CONSOLE.md` asks
/// for a diff and a blast radius *before* the decision, and a validator that
/// only runs when you press the button is a validator that tells you after you
/// have committed to the idea.
@immutable
final class DraftReview {
  /// Describes a reviewed draft.
  const DraftReview({
    required this.changes,
    required this.problems,
    required this.publishable,
    required this.blastRadius,
  });

  /// What differs from the base version.
  final List<ConfigChange> changes;

  /// Why it cannot be published, if it cannot.
  final List<ConfigProblem> problems;

  /// The validated draft, or `null` when [problems] is not empty.
  final PublishableConfig? publishable;

  /// What the change would still reach.
  final BlastRadius blastRadius;

  /// Whether anything at all is being proposed.
  bool get isEmpty => changes.isEmpty;
}

/// The draft, checked against the catalogue and the clock.
final FutureProvider<DraftReview?> draftReviewProvider =
    FutureProvider<DraftReview?>((ref) async {
      final draft = ref.watch(draftProvider);
      if (draft == null) return null;

      final catalogue = ref.watch(catalogueProvider);
      final cities = await ref.watch(citiesProvider.future);
      final inFlight = await ref.watch(inFlightProvider.future);
      final now = ref.watch(clockProvider).nowUtc();

      final validated = draft.validate(
        catalogue: catalogue,
        now: now,
        targets: targetsFor(cities.map((city) => city.id)),
      );

      return DraftReview(
        changes: draft.changes(catalogue),
        problems: validated.errorOrNull ?? const [],
        publishable: validated.valueOrNull,
        blastRadius: BlastRadius.estimate(
          inFlight: inFlight,
          effectiveFrom: draft.effectiveFrom,
        ),
      );
    });
