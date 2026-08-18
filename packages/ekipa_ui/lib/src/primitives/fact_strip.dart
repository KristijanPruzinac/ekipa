import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// One labelled fact: a small mono key over its value.
///
/// The layout is lifted from the reference set — Opal's metric pills under a
/// hero object, Posh's `RSVP 1 · Page visits 2` pair.
/// `docs/reference/README.md` names it as the shape for a hangout's facts:
/// **time · place · who**.
///
/// Note what it is *not* used for. The same reference file is explicit that
/// Opal's score gauge is the thing to leave behind, because there is no number
/// this product may show a person about themselves (`04_TRUST.md` — standing is
/// never visible, and a visible one becomes a status game inside a week). So a
/// [Fact] carries facts about an *evening*, never a measurement of a person.
class Fact {
  /// A fact called [key] whose value is [value].
  const Fact(this.key, this.value, {this.tone = ZarColors.ink});

  /// The small caps label. Two or three words at most.
  final String key;

  /// The fact itself.
  final String value;

  /// Colours the value — [ZarColors.mint] for confirmed, [ZarColors.amber] for
  /// waiting, [ZarColors.rose] for cancelled. Defaults to plain ink.
  final Color tone;
}

/// Lays [facts] out in a row, evenly, with a hairline between each.
///
/// Wraps to a column when the text scale or a narrow screen would squeeze the
/// values — a fact that has been ellipsised is not a fact.
class FactStrip extends StatelessWidget {
  /// Renders [facts] side by side.
  const FactStrip(this.facts, {super.key});

  /// The facts, left to right. Three is the comfortable maximum.
  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final base = ZarType.mono.fontSize!;
    final scaled = MediaQuery.textScalerOf(context).scale(base);
    final stacked = facts.length > 2 && scaled > base * 1.3;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final fact in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: ZarSpace.sm),
              child: _FactCell(fact),
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0)
            Container(
              width: ZarLayout.hairline,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: ZarSpace.md),
              color: ZarColors.hairline,
            ),
          Expanded(child: _FactCell(facts[i])),
        ],
      ],
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell(this.fact);

  final Fact fact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: fact.key,
    value: fact.value,
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(fact.key.toUpperCase(), style: ZarType.monoKey),
        const SizedBox(height: ZarSpace.xxs),
        Text(fact.value, style: ZarType.mono.copyWith(color: fact.tone)),
      ],
    ),
  );
}
