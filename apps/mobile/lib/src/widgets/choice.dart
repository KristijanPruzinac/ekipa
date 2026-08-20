/// The app's two ways of choosing something.
///
/// **Intention — a choice looks chosen without relying on colour alone.** The
/// palette has one accent and the design system spends it sparingly, so a
/// selected row is marked by its border, its ground *and* a mark, which is also
/// what makes it legible to somebody who cannot separate ember from ink.
///
/// Both controls are ordinary buttons to a screen reader: they announce their
/// label, that they are a button, and whether they are selected. That is not a
/// bonus — the availability picker is nine controls that differ only by a time,
/// and an unlabelled grid of them is unusable.
library;

import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One option in a vertical list — a gender, a city.
class ChoiceRow extends StatelessWidget {
  /// A row labelled [label], selected or not.
  const ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
    super.key,
  });

  /// What the option is.
  final String label;

  /// One quiet line under it, where the option needs one.
  final String? note;

  /// Whether it is the current answer.
  final bool selected;

  /// Chooses it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: ZarRadius.allMd,
      child: Container(
        constraints: const BoxConstraints(minHeight: ZarLayout.controlHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: ZarSpace.md,
          vertical: ZarSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? ZarColors.emberWash : ZarColors.surface,
          borderRadius: ZarRadius.allMd,
          border: Border.all(
            color: selected ? ZarColors.ember : ZarColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: ZarType.body),
                  if (note case final String line) ...[
                    const SizedBox(height: ZarSpace.xxs),
                    Text(line, style: ZarType.caption),
                  ],
                ],
              ),
            ),
            // A drawn mark rather than a Material tick. The design system has
            // no icon set and does not want one: a glyph from a font nobody
            // chose is the kind of detail that makes a screen look assembled
            // instead of designed, and it is one more thing to load.
            if (selected)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ZarColors.ember,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// One slot in the availability picker.
///
/// **Intention — the tap target is the whole tile.** A checkbox beside a time
/// is two targets for one decision, and on a phone the small one gets missed.
/// `ZarLayout.minTapTarget` is the floor and this sits above it.
class SlotChip extends StatelessWidget {
  /// A chip for the slot starting at [time].
  const SlotChip({
    required this.time,
    required this.chosen,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  /// Local wall-clock start, `HH:mm`.
  final String time;

  /// Whether the person said they are free.
  final bool chosen;

  /// Whether it can still be answered.
  final bool enabled;

  /// Toggles it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = !enabled
        ? ZarColors.inkFaint
        : chosen
        ? ZarColors.ember
        : ZarColors.ink;
    return Semantics(
      button: true,
      selected: chosen,
      enabled: enabled,
      label: '$time, ${chosen ? 'free' : 'not free'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: ZarRadius.allMd,
        child: Container(
          height: ZarLayout.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chosen ? ZarColors.emberWash : ZarColors.surface,
            borderRadius: ZarRadius.allMd,
            border: Border.all(
              color: chosen ? ZarColors.ember : ZarColors.hairline,
            ),
          ),
          child: Text(
            time,
            style: ZarType.body.copyWith(color: ink),
          ),
        ),
      ),
    );
  }
}

/// A quiet line of text the app was handed rather than one it composed.
class Verbatim extends StatelessWidget {
  /// Prints [text] as given.
  const Verbatim(this.text, {this.tone, super.key});

  /// The text.
  final String text;

  /// An optional colour.
  final Color? tone;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: ZarType.body.copyWith(color: tone));
}

/// What to show while a provider is loading, and when it failed.
class AsyncBlock<T> extends StatelessWidget {
  /// Creates a block for [value].
  const AsyncBlock({required this.value, required this.builder, super.key});

  /// The provider's state.
  final AsyncValue<T> value;

  /// What to build when it has data.
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.symmetric(vertical: ZarSpace.xxl),
      child: Center(
        child: SizedBox(
          height: 2,
          width: 96,
          child: LinearProgressIndicator(
            backgroundColor: ZarColors.hairline,
            color: ZarColors.inkFaint,
          ),
        ),
      ),
    ),
    // The server's own words. An app that rewrote them would be inventing a
    // second explanation of a rule it does not own.
    error: (error, _) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZarSpace.md),
      decoration: BoxDecoration(
        color: ZarColors.surface,
        borderRadius: ZarRadius.allMd,
        border: Border.all(color: ZarColors.rose),
      ),
      child: Verbatim('$error', tone: ZarColors.ink),
    ),
  );
}
