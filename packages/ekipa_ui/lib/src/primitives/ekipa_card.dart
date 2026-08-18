import 'package:ekipa_ui/src/primitives/pressable.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:flutter/widgets.dart';

/// A surface holding one thing.
///
/// Flat: a fill, a hairline, a radius, and no shadow. *Rejected — elevation:* a
/// drop shadow on a near-black ground is either invisible or a grey smear, and
/// the reference set (Opal, Posh) separates layers by value alone. One less
/// dimension to keep consistent.
class EkipaCard extends StatelessWidget {
  /// A card containing [child].
  const EkipaCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ZarSpace.lg),
    this.tone = EkipaCardTone.plain,
    super.key,
  });

  /// What the card holds.
  final Widget child;

  /// Makes the whole card a target. `null` leaves it inert.
  final VoidCallback? onTap;

  /// Space between the card's edge and [child].
  final EdgeInsetsGeometry padding;

  /// Which of the two registers the card belongs to.
  final EkipaCardTone tone;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: switch (tone) {
          EkipaCardTone.plain => ZarColors.surface,
          EkipaCardTone.live => ZarColors.surface,
          EkipaCardTone.quiet => ZarColors.ground,
        },
        borderRadius: ZarRadius.allMd,
        border: Border.all(
          color: switch (tone) {
            EkipaCardTone.plain => ZarColors.hairline,
            EkipaCardTone.live => ZarColors.ember,
            EkipaCardTone.quiet => ZarColors.hairline,
          },
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;
    return Pressable(onPressed: onTap, child: card);
  }
}

/// What a card is saying about its own importance.
enum EkipaCardTone {
  /// The default. A fact, a group, a slot.
  plain,

  /// The one card on the screen that is happening now — tonight's hangout, the
  /// confirmation that is open. Bordered in ember, and there is never more than
  /// one, because two live things means neither is.
  live,

  /// A card that is on the screen for reference and is not being decided about.
  quiet,
}
