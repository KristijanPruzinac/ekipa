/// The console's shared parts.
///
/// **Intention — no widget in this file composes a sentence about the domain.**
/// Every string a screen shows about a rule, a refusal or a consequence arrives
/// as text from `ekipa_core` or from the server: `ConfigProblem.detail`,
/// `BlastRadius.describe()`, `ConsoleFailure.message`. The widgets supply
/// labels for their own furniture — "Scope", "Reason", "Refused" — and nothing
/// else.
///
/// That rule is worth stating because the alternative is so natural. A screen
/// that writes "This change affects 3 hangouts" has quietly become a second
/// implementation of what "affects" means, and the day the definition changes
/// in `BlastRadius`, the screen keeps saying the old thing with total
/// confidence.
library;

import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A titled block of the console.
class ConsoleSection extends StatelessWidget {
  /// Creates a section.
  const ConsoleSection({
    required this.title,
    required this.child,
    this.lede,
    this.trailing,
    super.key,
  });

  /// The section's name.
  final String title;

  /// One supporting line, where the section needs one.
  final String? lede;

  /// A control belonging to the section as a whole.
  final Widget? trailing;

  /// The section's content.
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ConsoleType.section),
                if (lede case final String text) ...[
                  const SizedBox(height: ZarSpace.xxs),
                  Text(text, style: ConsoleType.note),
                ],
              ],
            ),
          ),
          if (trailing case final Widget control) control,
        ],
      ),
      const SizedBox(height: ZarSpace.md),
      child,
    ],
  );
}

/// A hairline-separated table.
class ConsoleTable extends StatelessWidget {
  /// Creates a table.
  const ConsoleTable({required this.columns, required this.rows, super.key});

  /// Column headers, paired with their flex weight.
  final List<({String label, int flex, bool numeric})> columns;

  /// The rows, each holding one widget per column.
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Hollow('Nothing here yet.');
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZarColors.surface,
        borderRadius: ZarRadius.allMd,
        border: Border.all(color: ZarColors.hairline),
      ),
      child: Column(
        children: [
          _TableRow(
            isHeader: true,
            columns: columns,
            cells: [
              for (final column in columns)
                Text(column.label.toUpperCase(), style: ConsoleType.columnHead),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            _TableRow(
              columns: columns,
              cells: rows[i],
              last: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.columns,
    required this.cells,
    this.isHeader = false,
    this.last = false,
  });

  final List<({String label, int flex, bool numeric})> columns;
  final List<Widget> cells;
  final bool isHeader;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: ConsoleSpace.rowHeight),
    padding: const EdgeInsets.symmetric(
      horizontal: ZarSpace.md,
      vertical: ZarSpace.xs,
    ),
    decoration: BoxDecoration(
      border: last || isHeader && cells.isEmpty
          ? null
          : const Border(
              bottom: BorderSide(color: ZarColors.hairline),
            ),
    ),
    child: Row(
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: ConsoleSpace.cellGap),
          Expanded(
            flex: columns[i].flex,
            child: Align(
              alignment: columns[i].numeric
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: i < cells.length ? cells[i] : const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Where a resolved value came from.
///
/// **Intention.** This chip is the reason `ConfigResolver` returns origins at
/// all. Without it the console shows a number and the operator has to guess
/// whether editing the global layer will move it — and the answer is often no,
/// because a city override is sitting on top. The chip turns "why is this 3?"
/// from a question into a thing already on screen.
class ScopeChip extends StatelessWidget {
  /// Creates a chip for [scope].
  const ScopeChip(this.scope, {this.overridden = false, super.key});

  /// The layer the value came from.
  final ConfigScope? scope;

  /// Whether this layer is being shadowed by a more specific one.
  final bool overridden;

  @override
  Widget build(BuildContext context) {
    final layer = scope;
    // A city reference is a uuid, and the column it sits in is a fifth of the
    // table. Shortened rather than ellipsised, so the chip reads the same on
    // every screen width and a test can name what it should say; the tooltip
    // carries the whole thing for anyone who needs to match it against a row.
    final label = layer == null
        ? 'default'
        : layer.ref.isEmpty
        ? layer.kind.name
        : '${layer.kind.name}:${_shortRef(layer.ref)}';
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZarSpace.xs,
        vertical: ZarSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: ZarColors.surfaceRaised,
        borderRadius: ZarRadius.allSm,
        border: Border.all(color: ZarColors.hairline),
      ),
      child: Text(
        label,
        style: ConsoleType.chip.copyWith(
          color: overridden ? ZarColors.inkFaint : ZarColors.inkMuted,
        ),
      ),
    );
    return layer == null || layer.ref.length <= _refLength
        ? chip
        : Tooltip(message: layer.toString(), child: chip);
  }
}

/// How much of a scope reference the chip shows.
const int _refLength = 8;

String _shortRef(String ref) =>
    ref.length <= _refLength ? ref : ref.substring(0, _refLength);

/// The mark on a key whose value can hurt somebody.
///
/// One of the three places ember is spent. `ConfigKey.safetyCritical` carries
/// the mark, so a screen written next year cannot forget the list.
class SafetyMark extends StatelessWidget {
  /// Creates the mark.
  const SafetyMark({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Safety-critical. Changing this needs a typed reason.',
    child: Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: ZarColors.ember,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// The panel shown when a draft cannot be published.
///
/// Prints [ConfigProblem.detail] verbatim, one per line. The console adds the
/// word "Refused" and nothing else — see the library comment above.
class ProblemPanel extends StatelessWidget {
  /// Creates the panel.
  const ProblemPanel(this.problems, {super.key});

  /// What is wrong, from `ConfigDraft.validate`.
  final List<ConfigProblem> problems;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZarSpace.md),
      decoration: BoxDecoration(
        color: ZarColors.surface,
        borderRadius: ZarRadius.allMd,
        border: Border.all(color: ZarColors.rose),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REFUSED',
            style: ConsoleType.columnHead.copyWith(color: ZarColors.rose),
          ),
          const SizedBox(height: ZarSpace.xs),
          for (final problem in problems) ...[
            Padding(
              padding: const EdgeInsets.only(top: ZarSpace.xxs),
              child: Text(problem.detail, style: ZarType.body),
            ),
          ],
        ],
      ),
    );
  }
}

/// A one-line statement the console was handed, rather than one it composed.
class Verbatim extends StatelessWidget {
  /// Creates the line.
  const Verbatim(this.text, {this.tone, super.key});

  /// The text, printed as given.
  final String text;

  /// An optional colour for it.
  final Color? tone;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: ZarType.body.copyWith(color: tone));
}

/// The console's primary action. The second of the three ember spends.
class ConsoleAction extends StatelessWidget {
  /// Creates an action.
  const ConsoleAction({
    required this.label,
    required this.onPressed,
    this.tone = EkipaButtonTone.primary,
    super.key,
  });

  /// The word on it.
  final String label;

  /// What it does, or `null` when it cannot be pressed.
  final VoidCallback? onPressed;

  /// Which register it belongs to.
  final EkipaButtonTone tone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    child: EkipaButton(label: label, onPressed: onPressed, tone: tone),
  );
}

/// What to show while a provider is loading, and when it failed.
///
/// **Intention.** A failure here is nearly always the server refusing, and the
/// message is the server's. `ConsoleFailure.isRefusal` separates "you may not"
/// from everything else, because the two need different next steps: a refusal
/// after a working session usually means a token expired, not that a permission
/// changed under the operator.
class AsyncBlock<T> extends StatelessWidget {
  /// Creates a block for [value].
  const AsyncBlock({required this.value, required this.builder, super.key});

  /// The provider's current state.
  final AsyncValue<T> value;

  /// What to build when it has data.
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(ZarSpace.lg),
      child: SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          backgroundColor: ZarColors.hairline,
          color: ZarColors.inkFaint,
        ),
      ),
    ),
    error: (error, _) {
      final failure = error is ConsoleFailure
          ? error
          : ConsoleFailure(error.toString());
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZarSpace.md),
        decoration: BoxDecoration(
          color: ZarColors.surface,
          borderRadius: ZarRadius.allMd,
          border: Border.all(
            color: failure.isRefusal ? ZarColors.amber : ZarColors.rose,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failure.isRefusal ? 'REFUSED BY THE SERVER' : 'FAILED',
              style: ConsoleType.columnHead.copyWith(
                color: failure.isRefusal ? ZarColors.amber : ZarColors.rose,
              ),
            ),
            const SizedBox(height: ZarSpace.xs),
            Verbatim(failure.message),
          ],
        ),
      );
    },
  );
}

class _Hollow extends StatelessWidget {
  const _Hollow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ZarSpace.lg),
    decoration: BoxDecoration(
      borderRadius: ZarRadius.allMd,
      border: Border.all(color: ZarColors.hairline),
    ),
    child: Text(text, style: ConsoleType.note),
  );
}
