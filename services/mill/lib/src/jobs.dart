import 'dart:io';

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:mill/src/postgrest.dart';
import 'package:mill/src/snapshot_codec.dart';

/// What the mill can be asked to do.
///
/// **Two jobs, and they are deliberately different shapes.** The match run is
/// heavy, runs once a day per city, and either lands whole or not at all. The
/// sweep is light, runs every few minutes, and advances whatever the clock says
/// is due — one hangout at a time, so a failure costs one transition rather
/// than a night.
///
/// **Neither job holds state.** If the process dies mid-run the next invocation
/// recomputes from the database, which is what lets this be a cron job on a
/// free tier rather than a service somebody has to keep alive (D9, tier 0).
final class Mill {
  /// Creates a mill talking to [_db], reading the clock through [_clock].
  const Mill(this._db, this._clock);

  final Postgrest _db;
  final Clock _clock;

  // ── The match run ──────────────────────────────────────────────────────────

  /// Forms groups for every city that is open.
  ///
  /// **Intention — launching a second city must be a row, not a deploy.** The
  /// nightly job names no city; it asks which are `active` and matches those.
  /// D11 says the product must not need ongoing per-city labour, and a city
  /// list in a workflow file is exactly that labour, arriving once per city and
  /// forever afterwards whenever the list is wrong.
  ///
  /// **One city's failure does not cancel another city's evening.** The two
  /// runs share nothing — different people, different slots, different venues —
  /// so a snapshot that will not decode in one is not a reason to leave the
  /// other unmatched. A refusal is different and rethrows: it means the key is
  /// not `service_role`, and every remaining city would fail the same way.
  Future<List<RunReport>> matchAll({
    required ConfigSnapshot config,
    int? seed,
  }) async {
    final raw = await _db.rpc('worker_cities');
    final cities = raw as List<Object?>? ?? const [];
    final reports = <RunReport>[];

    for (final entry in cities) {
      final row = entry! as Map<String, Object?>;
      try {
        reports.add(
          await matchCity(
            CityId(row['id']! as String),
            config: config,
            seed: seed,
          ),
        );
      } on PostgrestFailure catch (failure) {
        if (failure.isRefusal) rethrow;
        // Named, because a city that silently produced no groups looks exactly
        // like a city where nobody was free — and those need different
        // responses from whoever reads the log.
        stderr.writeln('mill: ${row['name']} failed: $failure');
      }
    }
    return reports;
  }

  /// Forms groups for one city.
  ///
  /// One snapshot, one pure call, one transactional write. The seed is derived
  /// from the city and the day rather than from a random source, so **running
  /// the job twice on the same day produces the same plan** — the second run's
  /// groups collide with the first's on the one-per-slot index and are skipped,
  /// instead of forming a second, different set of groups from the people the
  /// first run left over.
  Future<RunReport> matchCity(
    CityId city, {
    required ConfigSnapshot config,
    int? seed,
  }) async {
    final matchConfig = MatchConfig.from(config);
    final now = _clock.nowUtc();
    final horizon = Duration(days: config.get(LifecycleKeys.matchHorizonDays));

    final raw = await _db.rpc('worker_snapshot', {
      'p_city_id': city.value,
      'p_from': now.toIso8601String(),
      'p_to': now.add(horizon).toIso8601String(),
      'p_max_travel_m': config.get(LifecycleKeys.maxTravelMetres),
    });

    final snapshot = readSnapshot(raw! as Map<String, Object?>);
    if (snapshot.slots.isEmpty || snapshot.populationSize == 0) {
      return RunReport(city: city, written: 0, skipped: 0, considered: 0);
    }

    final plan = const Matchmaker().run(
      snapshot,
      matchConfig,
      seed ?? _seedFor(city, now),
    );

    if (plan.hangouts.isEmpty) {
      // A thin night is a normal outcome, not a failure. The funnel says why —
      // filtered by cooldown, by standing, by distance — and it is the only
      // thing that makes a quiet Thursday explainable rather than mysterious.
      return RunReport(
        city: city,
        written: 0,
        skipped: 0,
        considered: plan.stats.eligibleConsidered,
      );
    }

    final answer = await _db.rpc('worker_commit_plan', {
      'p_plan': writePlan(
        plan,
        config: config,
        snapshot: snapshot,
        kind: 'daily',
      ),
    });

    final result = answer! as Map<String, Object?>;
    return RunReport(
      city: city,
      written: (result['written'] as num?)?.toInt() ?? 0,
      skipped: (result['skipped'] as num?)?.toInt() ?? 0,
      considered: plan.stats.eligibleConsidered,
    );
  }

  /// The seed for a city's run on a given day.
  ///
  /// **Derived, not random.** `03_MATCHMAKER.md`: the same snapshot and seed
  /// must produce a byte-identical plan, and that is only checkable if the seed
  /// is reproducible from something written down. City plus date is written
  /// down twice — on the `match_run` row and in the calendar.
  ///
  /// FNV-1a for the same reason `SeededRandomSource` uses it: `String.hashCode`
  /// is not stable across platforms or releases, so a seed built on it would
  /// differ between CI and a laptop and would fail *silently*.
  static int _seedFor(CityId city, DateTime day) {
    final key = '${city.value}:${day.year}-${day.month}-${day.day}';
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  // ── The sweep ──────────────────────────────────────────────────────────────

  /// Advances every hangout the clock says is due.
  ///
  /// **One at a time, and a failure does not stop the rest.** These transitions
  /// are independent — one group's confirmation resolving has nothing to do
  /// with another's reveal — so a single bad row must not hold up an evening
  /// belonging to people who have done nothing wrong. Failures are counted and
  /// reported; the scheduler decides what a non-zero count means.
  Future<SweepReport> sweep({required ConfigSnapshot config}) async {
    final due = await _db.rpc('worker_due', {'p_limit': 200});
    final rows = due as List<Object?>? ?? const [];

    final params = _sweepParams(config);
    final moved = <String, int>{};
    var failed = 0;

    for (final row in rows) {
      final hangout = (row! as Map<String, Object?>)['hangout']! as String;
      try {
        final answer = await _db.rpc('worker_advance', {
          'p_hangout_id': hangout,
          'p_params': params,
        });
        final to = (answer! as Map<String, Object?>)['to'] as String? ?? '?';
        moved[to] = (moved[to] ?? 0) + 1;
      } on PostgrestFailure catch (failure) {
        // A refusal here means the key is not `service_role`, which is a
        // deployment fault rather than a data one. Nothing later in the loop
        // can succeed, so stop instead of failing two hundred times.
        if (failure.isRefusal) rethrow;
        failed++;
      }
    }

    return SweepReport(considered: rows.length, moved: moved, failed: failed);
  }

  /// The resolved settings `worker_advance` runs under.
  ///
  /// Sent explicitly rather than defaulted in SQL, so the version that produced
  /// a sanction is the version recorded on it. The database's own fallbacks
  /// exist for the case where this map is somehow incomplete, and they are
  /// deliberately the same numbers — a silent disagreement between the two
  /// would be a rule nobody could read.
  Map<String, Object?> _sweepParams(ConfigSnapshot config) => {
    'min_group_size': config.get(MatchingKeys.minGroupSize),
    'max_travel_m': config.get(LifecycleKeys.maxTravelMetres),
    'min_arrivals': config.get(TrustKeys.minArrivalsToCount),
    'config_version': config.versionId.value == 'defaults'
        ? null
        : config.versionId.value,
    'edge_strong': config.get(TrustKeys.edgeStrong),
    'edge_warm': config.get(TrustKeys.edgeWarm),
    'weights': {
      'CONFIRM_DECLINE': config.get(TrustKeys.declineWeight),
      'CONFIRM_DECLINE_LATE': config.get(TrustKeys.lateDeclineWeight),
      'CONFIRM_SILENT': config.get(TrustKeys.silenceWeight),
      'NO_SHOW': config.get(TrustKeys.noShowWeight),
      'LATE_ARRIVAL': config.get(TrustKeys.lateArrivalWeight),
      'RATING_MISSED': config.get(TrustKeys.missedRatingWeight),
      'EQUIPMENT_PROMISED_NOT_BROUGHT': config.get(TrustKeys.equipmentWeight),
    },
  };
}

/// What one city's match run did.
final class RunReport {
  /// Records a run.
  const RunReport({
    required this.city,
    required this.written,
    required this.skipped,
    required this.considered,
  });

  /// Which city.
  final CityId city;

  /// Hangouts created.
  final int written;

  /// Groups the one-per-slot index refused, which is a normal condition.
  final int skipped;

  /// How many eligible people the run looked at.
  final int considered;

  @override
  String toString() =>
      'match ${city.value}: $written written, $skipped skipped, '
      '$considered considered';
}

/// What one sweep did.
final class SweepReport {
  /// Records a sweep.
  const SweepReport({
    required this.considered,
    required this.moved,
    required this.failed,
  });

  /// How many hangouts were due.
  final int considered;

  /// How many landed in each state.
  final Map<String, int> moved;

  /// How many refused to move, for a reason that was not a permission.
  final int failed;

  @override
  String toString() {
    final parts = moved.entries.map((e) => '${e.key} ${e.value}').toList()
      ..sort();
    return 'sweep: $considered due, ${parts.join(', ')}'
        '${failed == 0 ? '' : ', $failed failed'}';
  }
}
