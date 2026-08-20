import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/data/records.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The [ConsoleGateway] backed by the real project.
///
/// **Intention — every method is one `rpc` call and nothing else.** There is no
/// `.from('config_versions').select()` anywhere in this file, and there cannot
/// be one that works: migration 0009 leaves the tables closed to the console's
/// roles, so a direct table read is refused by Postgres rather than by review.
/// This class is the adapter for that shape, not a general Supabase client.
///
/// It also holds no credential beyond the session the user signed in with. The
/// service-role key is not read here, not passed in, and not present in any
/// build this file is compiled into (AC-4, and `CONSOLE-NO-SERVICE-KEY` in
/// `tools/lint`).
final class SupabaseConsoleGateway implements ConsoleGateway {
  /// Wraps a Supabase client.
  const SupabaseConsoleGateway(this._client);

  final SupabaseClient _client;

  /// Calls [function], turning a Postgres refusal into a [ConsoleFailure].
  ///
  /// Every server error arrives here and leaves as the same type, so no screen
  /// has to know that the transport is PostgREST. The message is the server's
  /// own — see [ConsoleFailure] on why the client does not rewrite it.
  Future<T> _call<T>(
    String function,
    Map<String, Object?> params,
    T Function(Object? data) parse,
  ) async {
    try {
      final data = await _client.rpc<Object?>(function, params: params);
      return parse(data);
    } on PostgrestException catch (error) {
      throw ConsoleFailure(error.message, code: error.code);
    } on AuthException catch (error) {
      throw ConsoleFailure(error.message, code: error.statusCode);
    }
  }

  /// The rows of a `returns table (...)` result.
  static List<Map<String, Object?>> _rows(Object? data) => switch (data) {
    final List<Object?> list => [
      for (final row in list)
        if (row is Map) Map<String, Object?>.from(row),
    ],
    _ => const [],
  };

  static DateTime _utc(Object? raw) => DateTime.parse(raw! as String).toUtc();

  static int _int(Object? raw) => switch (raw) {
    final int value => value,
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  @override
  Future<String?> role() =>
      _call('admin_role', const {}, (data) => data as String?);

  @override
  Future<List<ConfigVersionRecord>> configVersions({int limit = 50}) => _call(
    'console_config_versions',
    {'p_limit': limit},
    (data) => [
      for (final row in _rows(data))
        ConfigVersionRecord(
          id: ConfigVersionId(row['id']! as String),
          createdAt: _utc(row['created_at']),
          effectiveFrom: _utc(row['effective_from']),
          note: (row['note'] as String?) ?? '',
          published: (row['published'] as bool?) ?? false,
          valueCount: _int(row['value_count']),
        ),
    ],
  );

  @override
  Future<List<ConfigValueRow>> configValues(ConfigVersionId versionId) => _call(
    'console_config_values',
    {'p_version_id': versionId.value},
    (data) => [
      for (final row in _rows(data))
        if (ConfigScopeCodec.decode(
              (row['scope_kind'] as String?) ?? '',
              (row['scope_ref'] as String?) ?? '',
            )
            case final ConfigScope scope)
          ConfigValueRow(
            key: row['key']! as String,
            scope: scope,
            value: row['value'],
          ),
    ],
  );

  @override
  Future<ConfigVersionId> publishConfig(
    PublishableConfig draft, {
    required String reason,
  }) => _call(
    'console_publish_config',
    {
      'p_note': draft.note,
      'p_effective_from': draft.effectiveFrom.toUtc().toIso8601String(),
      'p_values': [
        for (final row in draft.rows)
          {
            'key': row.key,
            'scope_kind': ConfigScopeCodec.kindOf(row.scope),
            'scope_ref': ConfigScopeCodec.refOf(row.scope),
            'value': row.value,
          },
      ],
      'p_reason': reason,
    },
    (data) => ConfigVersionId(data! as String),
  );

  @override
  Future<void> markPublished(
    ConfigVersionId versionId, {
    required String reason,
  }) => _call(
    'console_mark_published',
    {'p_version_id': versionId.value, 'p_reason': reason},
    (_) {},
  );

  @override
  Future<List<CityRecord>> cities() => _call(
    'console_cities',
    const {},
    (data) => [
      for (final row in _rows(data))
        CityRecord(
          id: CityId(row['id']! as String),
          name: (row['name'] as String?) ?? '',
          countryCode: (row['country_code'] as String?) ?? '',
          timezone: (row['timezone'] as String?) ?? 'UTC',
          active: (row['active'] as bool?) ?? false,
          slotCount: _int(row['slot_count']),
        ),
    ],
  );

  @override
  Future<List<SlotRecord>> slots({
    required CityId cityId,
    required DateTime from,
    required DateTime to,
  }) => _call(
    'console_slots',
    {
      'p_city_id': cityId.value,
      'p_from': _date(from),
      'p_to': _date(to),
    },
    (data) => [
      for (final row in _rows(data))
        SlotRecord(
          id: SlotId(row['id']! as String),
          startsAt: _utc(row['starts_at']),
          endsAt: _utc(row['ends_at']),
          localDate: (row['local_date'] as String?) ?? '',
          localWeekday: _int(row['local_weekday']),
          localTime: _time((row['local_time'] as String?) ?? ''),
          generatedBy: row['generated_by'] as String?,
          available: _int(row['available']),
        ),
    ],
  );

  @override
  Future<int> generateSlots({
    required CityId cityId,
    required List<LocalSlot> slots,
    required String generatedBy,
    required String reason,
  }) => _call(
    'console_generate_slots',
    {
      'p_city_id': cityId.value,
      'p_slots': [
        for (final slot in slots)
          {
            'local_date': slot.sqlDate,
            'local_time': slot.startsAt.sqlLiteral,
            'weekday': slot.weekday,
            'minutes': slot.duration.inMinutes,
          },
      ],
      'p_generated_by': generatedBy,
      'p_reason': reason,
    },
    _int,
  );

  @override
  Future<List<InFlightObject>> inFlight() => _call(
    'console_in_flight',
    const {},
    (data) => [
      for (final row in _rows(data))
        InFlightObject(
          id: row['id']! as String,
          kind: (row['kind'] as String?) ?? 'hangout',
          decidesAt: _utc(row['decides_at']),
          pinnedVersion: switch (row['config_version_id']) {
            final String id => ConfigVersionId(id),
            _ => null,
          },
        ),
    ],
  );

  @override
  Future<List<AuditRecord>> audit({int limit = 100}) => _call(
    'console_audit',
    {'p_limit': limit},
    (data) => [
      for (final row in _rows(data))
        AuditRecord(
          id: _int(row['id']),
          actor: (row['actor'] as String?) ?? '',
          action: (row['action'] as String?) ?? '',
          target: row['target'] as String?,
          reason: (row['reason'] as String?) ?? '',
          occurredAt: _utc(row['occurred_at']),
        ),
    ],
  );

  /// A `date` literal. Deliberately built from the calendar fields rather than
  /// from `toIso8601String()`, which would carry a time and a zone into a
  /// column that has neither.
  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Postgres renders `time` as `HH:MM:SS`; a schedule is read as `HH:MM`.
  static String _time(String raw) =>
      raw.length >= 5 ? raw.substring(0, 5) : raw;
}
