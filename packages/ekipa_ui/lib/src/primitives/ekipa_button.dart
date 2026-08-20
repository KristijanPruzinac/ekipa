import 'package:ekipa_ui/src/primitives/pressable.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// How much weight a button carries on the screen it is on.
enum EkipaButtonTone {
  /// The decision the screen exists to ask for. **One per screen.**
  primary,

  /// The other real option — "I can't make it" next to "I'll be there".
  secondary,

  /// A way out that must be available but must not compete: "not now", "skip".
  quiet,
}

/// The product's button.
///
/// `docs/reference/README.md` is unanimous across all four reference apps: one
/// question per screen, one field, one button, an escape hatch underneath. The
/// three tones are exactly that shape, and [EkipaButtonTone.primary] is
/// deliberately the only one that is filled — so "which one is the answer" is
/// never a reading exercise.
///
/// **Disabled is legible, not ghosted.** A greyed-out primary at 30% opacity is
/// the standard treatment and it is wrong here: it hides *what* the decision
/// would be at the exact moment someone is trying to work out why they cannot
/// make it yet. Disabled keeps AA contrast and loses only the fill.
class EkipaButton extends StatelessWidget {
  /// A button carrying [tone].
  const EkipaButton({
    required this.label,
    required this.onPressed,
    this.tone = EkipaButtonTone.primary,
    this.busy = false,
    super.key,
  });

  /// Names the action, in the words of the person doing it. "I'll be there",
  /// never "Submit".
  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  /// The button's weight on this screen.
  final EkipaButtonTone tone;

  /// Renders the in-flight state and refuses further taps.
  ///
  /// Every action in this product is a write with a consequence — a
  /// confirmation, an arrival, a rating — so a second tap while the first is in
  /// flight is a duplicate the server would have to defend against. It is
  /// cheaper to make it impossible.
  final bool busy;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch ((tone, _enabled)) {
      (EkipaButtonTone.primary, true) => (
        ZarColors.ember,
        ZarColors.emberInk,
        null,
      ),
      (EkipaButtonTone.primary, false) => (
        null,
        ZarColors.inkFaint,
        ZarColors.hairline,
      ),
      (EkipaButtonTone.secondary, true) => (null, ZarColors.ink, ZarColors.ink),
      (EkipaButtonTone.secondary, false) => (
        null,
        ZarColors.inkFaint,
        ZarColors.hairline,
      ),
      (EkipaButtonTone.quiet, true) => (null, ZarColors.inkMuted, null),
      (EkipaButtonTone.quiet, false) => (null, ZarColors.inkFaint, null),
    };

    return Pressable(
      onPressed: _enabled ? onPressed : null,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: ZarLayout.controlHeight,
          minWidth: ZarLayout.minTapTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ZarSpace.xl,
          vertical: ZarSpace.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: ZarRadius.allPill,
          // Width omitted: Border.all already defaults to ZarLayout.hairline,
          // and a test holds the token to that value so the two cannot drift.
          border: border == null ? null : Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: busy
            ? _BusyDots(colour: foreground)
            : Text(
                label,
                textAlign: TextAlign.center,
                style: ZarType.label.copyWith(color: foreground),
              ),
      ),
    );
  }
}

/// Three dots at the label's place while a write is in flight.
///
/// *Rejected — a spinner:* a spinner in a button changes the button's height as
/// the label leaves, and the layout shifting under a thumb at the moment of a
/// confirmation is how a double tap happens.
class _BusyDots extends StatelessWidget {
  const _BusyDots({required this.colour});

  final Color colour;

  // No semantics of its own: the button announces itself as disabled while a
  // write is in flight, which is the same thing these dots say visually.
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: i == 0 ? 1.0 : 0.45),
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );
}
