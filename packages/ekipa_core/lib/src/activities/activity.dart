import 'package:ekipa_core/src/foundation/random_source.dart';
import 'package:meta/meta.dart';

/// What an activity needs before it can be scheduled.
@immutable
final class ActivityRequirements {
  /// Describes what an activity needs.
  const ActivityRequirements({
    this.equipment,
    this.minCarriers = 0,
    this.minPeople = 3,
    this.needsSeating = false,
  });

  /// An equipment code from the registry, e.g. `deck_of_cards`.
  final String? equipment;

  /// How many members must carry it.
  final int minCarriers;

  /// The smallest group this works with.
  final int minPeople;

  /// Whether the meeting point has to have somewhere to sit.
  final bool needsSeating;
}

/// One card in a session.
@immutable
final class ActivityStep {
  /// Describes a step.
  const ActivityStep({
    required this.text,
    required this.note,
    this.intensity = 0,
  });

  /// What to read out.
  final String text;

  /// A line under it: which set, or how to play.
  final String note;

  /// How much self-disclosure it asks for, `0…3`.
  final int intensity;
}

/// An activity, as a strategy in a registry (D6).
///
/// **Intention — the third activity must not require touching the hangout
/// lifecycle.** Everything the platform does around an activity — reveal, the
/// rules screen, arrival taps, the ratings prompt — is the platform's
/// (`06_ACTIVITIES.md §4`). An activity supplies four things and nothing more.
///
/// **Every activity must supply an exit script.** Ambiguity is the tax this
/// population cannot afford, and the most expensive ambiguity in a social
/// meeting is *"is it over?"*. A stated end time plus a scripted goodbye
/// removes the single most dreaded moment of the evening. It is not decoration;
/// it is the reason people accept a second invitation.
abstract interface class ActivityTemplate {
  /// Registry id, e.g. `CONVERSATION_DECK`.
  String get id;

  /// What to call it on a screen.
  String get name;

  /// What happens, in one sentence, shown at confirmation and at reveal.
  String get brief;

  /// How it ends, in one sentence, shown at the same times.
  String get exitScript;

  /// What it needs.
  ActivityRequirements get requirements;

  /// What the first person to arrive should do.
  String get arrivalScript;

  /// The session, deterministic for a given [seed].
  ///
  /// **Why deterministic per hangout** (seeded from the hangout id): every
  /// member's phone shows the same card in the same order without any real-time
  /// synchronisation, and the content regenerates identically if somebody
  /// reinstalls mid-hangout. No round-trip, no "my phone shows a different
  /// question."
  List<ActivityStep> session(RandomSource seed, {required int people});
}

/// The activities this build knows about.
///
/// A registry, not a `switch`: `02_DOMAIN.md §8` lists five extension points
/// and this is one of them. Adding an activity is a class plus an entry.
abstract final class ActivityRegistry {
  static final Map<String, ActivityTemplate> _entries = {};

  /// Registers [template], replacing any entry with the same id.
  static void register(ActivityTemplate template) =>
      _entries[template.id] = template;

  /// The template called [id], or `null` if this build has never heard of it.
  ///
  /// `null` rather than a throw: a server that has been configured with a newer
  /// activity should cost an older client the *content*, not the evening. The
  /// caller falls back to the platform's own brief.
  static ActivityTemplate? find(String id) => _entries[id];

  /// Everything registered.
  static List<ActivityTemplate> get all => List.unmodifiable(_entries.values);
}
