import 'package:console/src/data/records.dart';
import 'package:console/src/state/providers.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:console/src/widgets/console_chrome.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The configuration editor.
///
/// **Intention — the screen answers "where did this value come from", not just
/// "what is it".** Every row carries the layer its value was resolved from, so
/// an operator editing the global layer can see at a glance that Osijek is
/// overriding it and their change will do nothing visible. That single chip is
/// the reason `ConfigResolver` returns origins at all.
///
/// **Publishing is on the same screen as editing, deliberately.** The diff, the
/// blast radius and the refusals belong beside the thing being changed; a
/// separate "review" page invites the operator to skim it on the way to the
/// button. Nothing here is a wizard.
class ConfigurationScreen extends ConsumerWidget {
  /// Creates the screen.
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = ref.watch(configVersionsProvider);
    final resolved = ref.watch(resolvedConfigProvider);
    final draft = ref.watch(draftProvider);

    return ListView(
      padding: const EdgeInsets.all(ZarSpace.xl),
      children: [
        AsyncBlock<List<ConfigVersionRecord>>(
          value: versions,
          builder: _VersionBar.new,
        ),
        const SizedBox(height: ConsoleSpace.blockGap),
        ConsoleSection(
          title: 'Configuration',
          lede:
              'Resolved for the selected city. The chip says which layer '
              'answered.',
          child: AsyncBlock<ConfigResolution?>(
            value: resolved,
            builder: (resolution) => _KeyTable(resolution: resolution),
          ),
        ),
        if (draft != null) ...[
          const SizedBox(height: ConsoleSpace.sectionGap),
          const _PublishPanel(),
        ],
        const SizedBox(height: ConsoleSpace.sectionGap),
      ],
    );
  }
}

/// Which version is on screen, and whether its rules are the ones in force.
class _VersionBar extends ConsumerWidget {
  const _VersionBar(this.versions);

  final List<ConfigVersionRecord> versions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (versions.isEmpty) {
      return const _NoVersions();
    }
    final active = ref.watch(activeVersionProvider).value;
    final now = ref.watch(clockProvider).nowUtc();
    final draft = ref.watch(draftProvider);
    final role = ref.watch(roleProvider).value;

    return EkipaCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DropdownButton<String>(
                      value: active?.id.value,
                      dropdownColor: ZarColors.surfaceRaised,
                      underline: const SizedBox.shrink(),
                      style: ConsoleType.value,
                      items: [
                        for (final version in versions)
                          DropdownMenuItem<String>(
                            value: version.id.value,
                            child: Text(
                              '${_stamp(version.effectiveFrom)}  '
                              '${_shortId(version.id.value)}',
                              style: ConsoleType.value,
                            ),
                          ),
                      ],
                      onChanged: (chosen) =>
                          ref.read(selectedVersionProvider.notifier).selected =
                              chosen == null ? null : ConfigVersionId(chosen),
                    ),
                    const SizedBox(width: ZarSpace.sm),
                    if (active != null) _VersionState(active, now: now),
                  ],
                ),
                if (active != null && active.note.isNotEmpty) ...[
                  const SizedBox(height: ZarSpace.xxs),
                  Verbatim(active.note),
                ],
              ],
            ),
          ),
          if (draft == null && atLeast(role, 'operator') && active != null)
            ConsoleAction(
              label: 'Start a change',
              tone: EkipaButtonTone.quiet,
              onPressed: () async {
                final rows = await ref.read(configValuesProvider.future);
                ref
                    .read(draftProvider.notifier)
                    .start(
                      baseVersionId: active.id,
                      baseRows: rows,
                      // An hour ahead rather than now: `console_publish_config`
                      // refuses a version that starts in the past, and "now" is
                      // in the past by the time the operator has typed a
                      // reason. Defaulting to a value the server rejects would
                      // teach people to ignore the refusal.
                      effectiveFrom: ref
                          .read(clockProvider)
                          .nowUtc()
                          .add(const Duration(hours: 1)),
                    );
              },
            ),
        ],
      ),
    );
  }
}

/// Live, scheduled, or a draft nobody released. The first of the three ember
/// spends: exactly one version on the list is the one deciding things now.
class _VersionState extends StatelessWidget {
  const _VersionState(this.version, {required this.now});

  final ConfigVersionRecord version;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (version) {
      final v when v.isLiveAt(now) => ('LIVE', ZarColors.ember),
      final v when v.published => ('SCHEDULED', ZarColors.amber),
      _ => ('UNPUBLISHED', ZarColors.inkFaint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZarSpace.xs,
        vertical: ZarSpace.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: ZarRadius.allPill,
        border: Border.all(color: colour),
      ),
      child: Text(label, style: ConsoleType.chip.copyWith(color: colour)),
    );
  }
}

class _NoVersions extends StatelessWidget {
  const _NoVersions();

  @override
  Widget build(BuildContext context) => const EkipaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No configuration has been published', style: ZarType.bodyStrong),
        SizedBox(height: ZarSpace.xxs),
        Text(
          'Every key below is running on the default compiled into the build. '
          'That is a valid state, not an error — but nothing is tunable until '
          'a first version exists.',
          style: ConsoleType.note,
        ),
      ],
    ),
  );
}

/// Every declared key, its resolved value, and the layer that answered.
class _KeyTable extends ConsumerWidget {
  const _KeyTable({required this.resolution});

  final ConfigResolution? resolution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final draft = ref.watch(draftProvider);
    final snapshot = resolution?.snapshot ?? ConfigSnapshot.defaults();

    return ConsoleTable(
      columns: const [
        (label: 'Key', flex: 5, numeric: false),
        (label: 'Value', flex: 2, numeric: true),
        (label: 'From', flex: 2, numeric: false),
        (label: '', flex: 1, numeric: true),
      ],
      rows: [
        for (final key in catalogue.keys)
          _row(
            context,
            ref,
            key: key,
            snapshot: snapshot,
            origin: resolution?.originOf(key.name),
            editing: draft != null,
          ),
      ],
    );
  }

  List<Widget> _row(
    BuildContext context,
    WidgetRef ref, {
    required ConfigKey<Object?> key,
    required ConfigSnapshot snapshot,
    required ConfigScope? origin,
    required bool editing,
  }) {
    final pending = _pendingEdit(ref, key.name);
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(key.name, style: ConsoleType.keyName)),
              if (key.safetyCritical) ...[
                const SizedBox(width: ZarSpace.xs),
                const SafetyMark(),
              ],
            ],
          ),
          const SizedBox(height: ZarSpace.xxs),
          // The key's own words, not a paraphrase. `ConfigKey.description` is
          // where the reason for a number lives; repeating it here in different
          // words would be a second definition to keep in step.
          Text(key.description, style: ConsoleType.note),
        ],
      ),
      if (editing)
        // Keyed by the key's own name. `_ValueField` holds a controller seeded
        // from the value it was built with, so without an identity of its own
        // it would be reused by position — and a catalogue that grew a group
        // would hand one key's controller to its neighbour.
        _ValueField(
          key: ValueKey<String>('value:${key.name}'),
          keyName: key.name,
          configKey: key,
          current: pending ?? snapshot.get(key),
        )
      else
        Text('${snapshot.get(key)}', style: ConsoleType.value),
      ScopeChip(origin, overridden: origin == null),
      const SizedBox.shrink(),
    ];
  }

  Object? _pendingEdit(WidgetRef ref, String keyName) {
    final draft = ref.watch(draftProvider);
    if (draft == null) return null;
    for (final edit in draft.edits) {
      if (edit.key == keyName) return edit.value;
    }
    return null;
  }
}

/// An editable value.
///
/// Writes at the **global** layer. City-level overrides are a P1 screen, and
/// shipping a scope picker that silently defaults to global is worse than not
/// shipping one: the operator would believe they had targeted a city.
class _ValueField extends ConsumerStatefulWidget {
  const _ValueField({
    required this.keyName,
    required this.configKey,
    required this.current,
    super.key,
  });

  final String keyName;
  final ConfigKey<Object?> configKey;
  final Object? current;

  @override
  ConsumerState<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends ConsumerState<_ValueField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.current}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final value = coerce(widget.configKey, text);
    final notifier = ref.read(draftProvider.notifier);
    if (value == null) {
      // An unparseable value is left in the field rather than swallowed. The
      // draft keeps the last good one, and `ConfigDraft.validate` will still
      // refuse anything the catalogue does not accept.
      return;
    }
    notifier.edit(
      key: widget.keyName,
      scope: const ConfigScope.global(),
      value: value,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: TextField(
      controller: _controller,
      style: ConsoleType.value,
      textAlign: TextAlign.right,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: ZarSpace.xs),
        enabledBorder: OutlineInputBorder(
          borderRadius: ZarRadius.allSm,
          borderSide: BorderSide(color: ZarColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ZarRadius.allSm,
          borderSide: BorderSide(color: ZarColors.focus),
        ),
      ),
      onChanged: _commit,
    ),
  );
}

/// Turns typed text into a value the key accepts, or `null`.
///
/// **Intention.** The key knows what it accepts — `ConfigKey.accepts` is the
/// same predicate the snapshot reads through — so the console offers candidates
/// and lets the key choose, rather than switching on the key's type itself. A
/// switch here would be a second copy of the type table, and it would be the
/// copy that forgets `Duration` when a sixth factory is added.
Object? coerce(ConfigKey<Object?> key, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final candidates = <Object>[
    ?int.tryParse(trimmed),
    ?double.tryParse(trimmed),
    if (trimmed == 'true') true,
    if (trimmed == 'false') false,
    trimmed,
  ];
  for (final candidate in candidates) {
    if (key.accepts(candidate)) return candidate;
  }
  return null;
}

/// The diff, the consequence, the reason, and the one button.
class _PublishPanel extends ConsumerStatefulWidget {
  const _PublishPanel();

  @override
  ConsumerState<_PublishPanel> createState() => _PublishPanelState();
}

class _PublishPanelState extends ConsumerState<_PublishPanel> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _serverRefusal;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _publish(PublishableConfig publishable) async {
    setState(() {
      _busy = true;
      _serverRefusal = null;
    });
    try {
      await ref
          .read(gatewayProvider)
          .publishConfig(publishable, reason: _reason.text.trim());
      ref.read(draftProvider.notifier).discard();
      ref
        ..invalidate(configVersionsProvider)
        ..invalidate(auditProvider);
    } on Object catch (error) {
      // Whatever the server said, verbatim. The console's own validation
      // already passed, so anything arriving here is something the client did
      // not know — which is exactly the case where paraphrasing loses the
      // information.
      setState(() => _serverRefusal = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(draftReviewProvider);
    final role = ref.watch(roleProvider).value;

    return ConsoleSection(
      title: 'Publishing',
      lede: 'Written unpublished. Nothing changes for anybody until released.',
      trailing: ConsoleAction(
        label: 'Discard',
        tone: EkipaButtonTone.quiet,
        onPressed: () => ref.read(draftProvider.notifier).discard(),
      ),
      child: AsyncBlock<DraftReview?>(
        value: review,
        builder: (data) {
          if (data == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiffTable(data.changes),
              const SizedBox(height: ZarSpace.lg),
              // Both fields are keyed. They are the two sentences the audit
              // trail keeps, and a test that had to find them by counting the
              // text fields on the screen would stop checking them the first
              // time a row was added above.
              _Field(
                key: const ValueKey<String>('field:note'),
                label: 'What this version is',
                controller: _note,
                onChanged: ref.read(draftProvider.notifier).setNote,
              ),
              const SizedBox(height: ZarSpace.md),
              _Field(
                key: const ValueKey<String>('field:reason'),
                label: 'Why you are changing it',
                controller: _reason,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: ZarSpace.lg),
              _BlastRadiusLine(data.blastRadius),
              const SizedBox(height: ZarSpace.lg),
              ProblemPanel(data.problems),
              if (_serverRefusal case final String refusal) ...[
                const SizedBox(height: ZarSpace.md),
                Verbatim(refusal, tone: ZarColors.rose),
              ],
              const SizedBox(height: ZarSpace.lg),
              ConsoleAction(
                label: _busy ? 'Writing…' : 'Write this version',
                onPressed:
                    data.publishable == null ||
                        _busy ||
                        _reason.text.trim().isEmpty ||
                        !atLeast(role, 'operator')
                    ? null
                    : () => _publish(data.publishable!),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiffTable extends StatelessWidget {
  const _DiffTable(this.changes);

  final List<ConfigChange> changes;

  @override
  Widget build(BuildContext context) => ConsoleTable(
    columns: const [
      (label: 'Key', flex: 5, numeric: false),
      (label: 'Was', flex: 2, numeric: true),
      (label: 'Becomes', flex: 2, numeric: true),
      (label: 'Layer', flex: 2, numeric: false),
    ],
    rows: [
      for (final change in changes)
        [
          Row(
            children: [
              Flexible(child: Text(change.key, style: ConsoleType.keyName)),
              if (change.safetyCritical) ...[
                const SizedBox(width: ZarSpace.xs),
                const SafetyMark(),
              ],
            ],
          ),
          Text('${change.before ?? '—'}', style: ConsoleType.valueWas),
          Text('${change.after ?? '—'}', style: ConsoleType.value),
          ScopeChip(change.scope),
        ],
    ],
  );
}

/// What the change would still reach, in `BlastRadius`'s own words.
class _BlastRadiusLine extends StatelessWidget {
  const _BlastRadiusLine(this.radius);

  final BlastRadius radius;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ZarSpace.md),
    decoration: BoxDecoration(
      color: ZarColors.surface,
      borderRadius: ZarRadius.allMd,
      border: Border.all(
        color: radius.isEmpty ? ZarColors.hairline : ZarColors.amber,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BLAST RADIUS', style: ConsoleType.columnHead),
        const SizedBox(height: ZarSpace.xs),
        Verbatim(radius.describe()),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: ConsoleType.columnHead),
      const SizedBox(height: ZarSpace.xs),
      TextField(
        controller: controller,
        style: ZarType.body,
        onChanged: onChanged,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.all(ZarSpace.sm),
          enabledBorder: OutlineInputBorder(
            borderRadius: ZarRadius.allSm,
            borderSide: BorderSide(color: ZarColors.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: ZarRadius.allSm,
            borderSide: BorderSide(color: ZarColors.focus),
          ),
        ),
      ),
    ],
  );
}

String _stamp(DateTime when) =>
    '${when.year}-${_two(when.month)}-${_two(when.day)} '
    '${_two(when.hour)}:${_two(when.minute)}Z';

String _two(int value) => value.toString().padLeft(2, '0');

String _shortId(String id) => id.length >= 8 ? id.substring(0, 8) : id;
