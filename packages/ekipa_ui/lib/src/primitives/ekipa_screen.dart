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
                  builder: (context, constraints) => _FadingScroll(
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

/// A scroll view that says so when there is more below.
///
/// **Intention — a hard clip at the fold reads as a bug, not as a scroll.** The
/// availability picker ends in a one-line legend, and on a short viewport that
/// line was sliced through the middle of a word by the edge of the scroll area.
/// Nothing about it suggested scrolling; it looked like text that had failed to
/// lay out. A short fade to the ground colour turns the same pixels into an
/// affordance.
///
/// It appears only when something is actually cut off, and fades out over the
/// last few pixels of travel, so a screen that fits shows nothing at all —
/// a permanent gradient would be decoration lying about the content.
///
/// *Rejected — a scrollbar:* it is the platform answer and it is the wrong one
/// here. A scrollbar is a control for *moving* through a long document; this is
/// one sentence of state about a short one, and every reference app in
/// `docs/reference/` uses the fade.
class _FadingScroll extends StatefulWidget {
  const _FadingScroll({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  State<_FadingScroll> createState() => _FadingScrollState();
}

class _FadingScrollState extends State<_FadingScroll> {
  final ScrollController _controller = ScrollController();
  double _fade = 0;

  /// How much travel the fade covers, in logical pixels.
  static const double _height = 32;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    // The first measurement cannot happen until there are dimensions, and
    // `initState` has none. Without this the fade is missing on arrival and
    // appears on the first touch, which is the one moment it is not needed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final remaining = position.maxScrollExtent - position.pixels;
    final next = (remaining / _height).clamp(0.0, 1.0);
    if ((next - _fade).abs() > 0.01) setState(() => _fade = next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: _height,
        child: IgnorePointer(
          child: Opacity(
            opacity: _fade,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00131719), ZarColors.ground],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
