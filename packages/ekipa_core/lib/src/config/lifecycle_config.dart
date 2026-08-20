import 'package:ekipa_core/src/config/catalogue.dart';
import 'package:ekipa_core/src/foundation/config.dart';

/// When each of a hangout's seven deadlines falls.
///
/// **Intention — the deadlines are written once, at creation, from the config
/// version in force at that moment** (`0003_v3_hangouts.sql`). That is what
/// stops a mid-day config change moving a deadline somebody is already inside.
/// Penalising a person under a rule that did not exist when they were asked is
/// the most trust-destroying bug this product can have, and it is invisible
/// without versioning.
///
/// Every value here is expressed **relative to the slot**, not as a clock time.
/// `08:00` is a different thing in June and December, and a rule that says "the
/// morning of" has to survive the slot moving from 16:00 to 19:00 without
/// anybody editing a second number.
///
/// **Rejected — deriving these from the slot in code.** They are behavioural
/// constants a product decision could reasonably move next month: shorten the
/// confirmation window, reveal ninety minutes early in winter, give the late
/// report longer. D5 says that makes them config keys, and the console's editor
/// lists them from this group.
abstract final class LifecycleKeys {
  /// How long before the slot the morning-of question opens.
  ///
  /// Ten hours puts a 17:30 slot's question at 07:30 — early enough that an
  /// answer arrives before the day fills up, late enough that it is about
  /// *today* rather than about a plan.
  static final ConfigKey<Duration> confirmOpensBefore = ConfigKey.duration(
    'lifecycle.confirm_opens_before',
    defaultValue: const Duration(hours: 10),
    description:
        'How long before the slot the confirmation question is asked. It has '
        'to read as "today", and it has to leave room to repair the group.',
  );

  /// How long a person has to answer.
  ///
  /// The scarce resource in this whole system is *time to repair*. This number
  /// is what is left of it after somebody says no, so shortening it costs
  /// backfill directly.
  static final ConfigKey<Duration> confirmWindow = ConfigKey.duration(
    'lifecycle.confirm_window',
    defaultValue: const Duration(hours: 4),
    description:
        'How long the confirmation stays open. Silence past this point is '
        'treated as a third answer, worse than a decline, because it destroys '
        'the repair window.',
    safetyCritical: true,
  );

  /// How long the repair pass may run after a decline.
  static final ConfigKey<Duration> backfillWindow = ConfigKey.duration(
    'lifecycle.backfill_window',
    defaultValue: const Duration(hours: 3),
    description:
        'How long the backfill may look for a replacement. It must end before '
        'the reveal: nobody learns where to go and then learns it is off.',
    safetyCritical: true,
  );

  /// How long before the slot the place, the sigil and the names appear.
  static final ConfigKey<Duration> revealBefore = ConfigKey.duration(
    'lifecycle.reveal_before',
    defaultValue: const Duration(hours: 1),
    description:
        'How long before the slot the meeting point and names are disclosed. '
        'Early names invite pre-judgement and quiet last-minute filtering.',
    safetyCritical: true,
  );

  /// How long after the start somebody may still arrive without it counting.
  ///
  /// People are late for ordinary reasons, and the product's own arrival screen
  /// says so out loud. A grace window that is shorter than the sentence on the
  /// screen would make the screen a lie.
  static final ConfigKey<Duration> arrivalGrace = ConfigKey.duration(
    'lifecycle.arrival_grace',
    defaultValue: const Duration(minutes: 15),
    description:
        'How long after the start an arrival is still on time. The arrival '
        'screen tells people this number, so the two move together.',
  );

  /// How long the group may report somebody absent.
  static final ConfigKey<Duration> lateReportWindow = ConfigKey.duration(
    'lifecycle.late_report_window',
    defaultValue: const Duration(minutes: 45),
    description:
        'How long after the start a no-show can still be attested. Past it, '
        'the evening is what it is and the record closes.',
  );

  /// How long after the end the ratings stay open.
  static final ConfigKey<Duration> ratingDueAfter = ConfigKey.duration(
    'lifecycle.rating_due_after',
    defaultValue: const Duration(hours: 24),
    description:
        'How long after the hangout ends the ratings are due. Until they are '
        'in, the person is not matched again — so this is also how long a '
        'forgetful person sits out.',
  );

  /// How far ahead the daily run forms groups.
  static final ConfigKey<int> matchHorizonDays = ConfigKey.integer(
    'lifecycle.match_horizon_days',
    defaultValue: 3,
    description:
        'How many days ahead the daily run matches. Far enough that a person '
        'has notice, near enough that they still know their own plans.',
  );

  /// How far somebody will plausibly travel across town.
  ///
  /// **This replaced a question we were asking people, and that was the point
  /// of removing it.** An earlier build had a "how far are you willing to go"
  /// control in onboarding; nothing in the transcript asks for one. The agreed
  /// rule is *match anywhere in town, ranked by closest distance*, so the
  /// number stops being a preference and becomes a property of the city — the
  /// radius beyond which a venue is not really in the same town.
  static final ConfigKey<int> maxTravelMetres = ConfigKey.integer(
    'geo.max_travel_m',
    defaultValue: 6000,
    description:
        'The radius, in metres, within which a venue cluster counts as '
        'reachable from a person’s anchor. A city property, not a '
        'preference: we match anywhere in town and rank by distance.',
  );

  /// Every key in this group.
  static final List<ConfigKey<Object?>> all = [
    confirmOpensBefore,
    confirmWindow,
    backfillWindow,
    revealBefore,
    arrivalGrace,
    lateReportWindow,
    ratingDueAfter,
    matchHorizonDays,
    maxTravelMetres,
  ];

  /// The group, for the console's editor.
  static final ConfigGroup group = ConfigGroup(
    name: 'Lifecycle',
    description:
        'When each of a hangout’s seven deadlines falls, relative to its '
        'slot, and how far across town counts as reachable.',
    keys: all,
    invariants: [
      // The ordering below is not tidiness. Each of these, violated, produces a
      // specific unkindness, and the console refuses to publish a version that
      // would.
      ConfigInvariant(
        name: 'the confirmation closes before the reveal',
        explanation:
            'Otherwise a person is told where to go while still being asked '
            'whether they are coming.',
        holds: (snapshot) =>
            snapshot.get(confirmOpensBefore) - snapshot.get(confirmWindow) >
            snapshot.get(revealBefore),
      ),
      ConfigInvariant(
        name: 'the backfill ends before the reveal',
        explanation:
            'Nobody learns the meeting point and then learns the evening is '
            'off. A cancellation has to land before anyone leaves home.',
        holds: (snapshot) =>
            snapshot.get(confirmOpensBefore) -
                snapshot.get(confirmWindow) -
                snapshot.get(backfillWindow) >=
            snapshot.get(revealBefore),
      ),
      ConfigInvariant(
        name: 'the late report outlasts the grace window',
        explanation:
            'A no-show can only be attested after the person has stopped '
            'being merely late.',
        holds: (snapshot) =>
            snapshot.get(lateReportWindow) > snapshot.get(arrivalGrace),
      ),
      ConfigInvariant(
        name: 'the match horizon reaches past the confirmation',
        explanation:
            'A group formed after its own confirmation would have opened is a '
            'group nobody can answer for.',
        holds: (snapshot) =>
            Duration(days: snapshot.get(matchHorizonDays)) >
            snapshot.get(confirmOpensBefore),
      ),
    ],
  );
}
