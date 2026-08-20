/// A [ConsoleGateway] that answers from memory, and records what it was asked.
///
/// **Intention — the console's tests must not be able to reach a server.**
/// Every screen here reads through the port, and both ports throw when nothing
/// overrides them, so a test that forgets this fake fails with a `StateError`
/// naming the missing override rather than hanging on a socket. That is the
/// property `gatewayProvider` exists to give, and this file is what makes using
/// it cheap enough that nobody works around it.
///
/// **It records calls as well as answering them.** Three of the guarantees this
/// suite has to check are about what the console *sent* — that a reason went
/// with a publish, that a viewer's UI never called a write at all — and a fake
/// that only returns values can prove neither.
library;

import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/data/records.dart';
import 'package:ekipa_core/ekipa_core.dart';

/// An in-memory console server.
final class FakeConsoleGateway implements ConsoleGateway {
  /// Creates a fake holding [versions], [cities] and the rest.
  FakeConsoleGateway({
    this.heldRole = 'operator',
    this.versions = const [],
    this.values = const [],
    this.cityList = const [],
    this.slotList = const [],
    this.inFlightList = const [],
    this.auditList = const [],
    this.refusal,
    this.writeRefusal,
  });

  /// What `role()` answers. `null` is "the database does not know you", which
  /// is also what an operator without a second factor gets.
  final String? heldRole;

  /// Stored config versions, newest first.
  final List<ConfigVersionRecord> versions;

  /// The values the active version carries.
  final List<ConfigValueRow> values;

  /// Known cities.
  final List<CityRecord> cityList;

  /// Materialised slots.
  final List<SlotRecord> slotList;

  /// Objects a rule change could still reach.
  final List<InFlightObject> inFlightList;

  /// The audit trail.
  final List<AuditRecord> auditList;

  /// When set, every method throws it. This is how a refused session is
  /// simulated: the server refuses uniformly, because the role check is the
  /// first statement of every function in migration 0009.
  final ConsoleFailure? refusal;

  /// When set, only the three writes throw it. This is the shape of a session
  /// that may read the console and may not change anything — a viewer with a
  /// client they wrote themselves — and the case the disabled button alone
  /// cannot prove anything about.
  final ConsoleFailure? writeRefusal;

  /// Every method called, in order, as `name` strings.
  final List<String> calls = [];

  /// The draft handed to [publishConfig], if one was.
  PublishableConfig? publishedDraft;

  /// The reason typed alongside it.
  String? publishedReason;

  /// The slots handed to [generateSlots], if any.
  List<LocalSlot>? generatedSlots;

  T _answer<T>(String name, T value) {
    calls.add(name);
    final refused = refusal;
    if (refused != null) throw refused;
    return value;
  }

  T _write<T>(String name, T value) {
    final refused = writeRefusal;
    if (refused != null) {
      calls.add(name);
      throw refused;
    }
    return _answer(name, value);
  }

  @override
  Future<String?> role() async => _answer('role', heldRole);

  @override
  Future<List<ConfigVersionRecord>> configVersions({int limit = 50}) async =>
      _answer('configVersions', versions);

  @override
  Future<List<ConfigValueRow>> configValues(ConfigVersionId versionId) async =>
      _answer('configValues', values);

  @override
  Future<ConfigVersionId> publishConfig(
    PublishableConfig draft, {
    required String reason,
  }) async {
    _write('publishConfig', null);
    publishedDraft = draft;
    publishedReason = reason;
    return const ConfigVersionId('00000000-0000-4000-8000-00000000dead');
  }

  @override
  Future<void> markPublished(
    ConfigVersionId versionId, {
    required String reason,
  }) async => _write('markPublished', null);

  @override
  Future<List<CityRecord>> cities() async => _answer('cities', cityList);

  @override
  Future<List<SlotRecord>> slots({
    required CityId cityId,
    required DateTime from,
    required DateTime to,
  }) async => _answer('slots', slotList);

  @override
  Future<int> generateSlots({
    required CityId cityId,
    required List<LocalSlot> slots,
    required String generatedBy,
    required String reason,
  }) async {
    _write('generateSlots', null);
    generatedSlots = slots;
    return slots.length;
  }

  @override
  Future<List<InFlightObject>> inFlight() async =>
      _answer('inFlight', inFlightList);

  @override
  Future<List<AuditRecord>> audit({int limit = 100}) async =>
      _answer('audit', auditList);
}
