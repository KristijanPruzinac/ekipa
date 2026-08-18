import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The shell every screen in the product is built inside.
///
/// It exists to make two rules structural rather than aspirational.
///
/// **One decision per screen.** [action] is a single slot. A screen that needs
/// two primary actions cannot express that here without saying so out loud by
/// putting a second button in [child], which is exactly the friction that
/// should exist. `docs/reference/README.md`: all four reference apps are
/// unanimous, and availability, confirmation, arrival and ratings are all
/// single-decision surfaces.
///
/// **The decision never scrolls away.** [child] scrolls; [action] is pinned
/// above the safe area, always. This is a v2 bug fixed structurally: content on
/// a short viewport used to push the button off-screen, and someone who cannot
/// see the button concludes the app is broken, not that they should scroll.
///
/// *Rejected — a plain `Scaffold` per screen:* it is what v1 did, and the
/// result was that no two screens shared a margin, a title size, or a scroll
/// behaviour, and the short-viewport bug had to be fixed once per screen.
class EkipaScreen extends StatelessWidget {
  /// A screen titled [title], asking for [action].
  const EkipaScreen({
    required this.child,
    this.title,
    this.lede,
    this.action,
    this.secondaryAction,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: ZarSpace.xl),
    super.key,
  });

  /// The screen's body. Scrolls when it does not fit.
  final Widget child;

  /// The one statement at the top. Omitted on screens that open with an object
  /// rather than a sentence — the reveal, the map.
  final String? title;

  /// One supporting line under [title]. One, not a paragraph: a screen that
  /// needs a paragraph to explain its question is asking the wrong question.
  final String? lede;

  /// The decision. Pinned to the bottom, never scrolled away.
  final Widget? action;

  /// The escape hatch under [action] — "I can't make it", "not now". The
  /// reference set's shape: one button, one way out underneath.
  final Widget? secondaryAction;

  /// Back, or close. Absent on screens that must be answered.
  final Widget? leading;

  /// Horizontal inset for [child]. Full-bleed screens pass [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZarColors.ground,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ZarLayout.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZarSpace.xs,
                    ZarSpace.xs,
                    ZarSpace.xs,
                    0,
                  ),
                  child: Align(alignment: Alignment.centerLeft, child: leading),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: leading == null ? ZarSpace.xl : ZarSpace.md,
                      bottom: ZarSpace.xl,
                    ),
                    child: ConstrainedBox(
                      // A short viewport scrolls; a tall one still lays the
                      // content out down the page rather than bunching it at
                      // the top.
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - ZarSpace.xl * 2,
                      ),
                      child: Padding(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null) ...[
                              Text(title!, style: ZarType.title),
                              const SizedBox(height: ZarSpace.sm),
                            ],
                            if (lede != null) ...[
                              Text(
                                lede!,
                                style: ZarType.body.copyWith(
                                  color: ZarColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: ZarSpace.xl),
                            ],
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (action != null || secondaryAction != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZarSpace.xl,
                    ZarSpace.md,
                    ZarSpace.xl,
                    ZarSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (action != null) action!,
                      if (secondaryAction != null) ...[
                        const SizedBox(height: ZarSpace.xs),
                        secondaryAction!,
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
