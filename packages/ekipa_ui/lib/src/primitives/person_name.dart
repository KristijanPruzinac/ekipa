import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// Renders a person's name, in the one format this product ever shows.
///
/// **The parameter type is the control.** [DisplayName] cannot be constructed
/// from arbitrary text — it is validated, and it owns the mask — so there is no
/// way to reach this widget with a full surname, a nickname, or anything else a
/// person typed. That is rule 11 of `docs/v3/11_SECURITY.md` §8 ("never let
/// free text reach a display name") enforced by the compiler instead of by
/// review.
///
/// *Rejected — `PersonName(String name)`:* one screen would eventually pass
/// `'$first $last'`, it would look correct in the simulator's fixtures, and it
/// would ship. A privacy rule that depends on every call site getting it right
/// is not a rule.
///
/// The serif and the sand colour are reserved for this widget and for
/// [VenueName]. When either appears, a human being or a real place is on screen
/// — that is the entire two-register argument in [ZarColors], and spending the
/// serif anywhere else spends the signal.
class PersonName extends StatelessWidget {
  /// Renders [name] at reading size.
  const PersonName(this.name, {this.hero = false, super.key});

  /// The masked name.
  final DisplayName name;

  /// Renders at hero size — for the one person a screen is about, which in
  /// practice means a rating card, never a list.
  final bool hero;

  @override
  Widget build(BuildContext context) => Text(
    name.masked,
    style: hero ? ZarType.personNameHero : ZarType.personName,
    // A screen reader saying "Marko dot dot dot dot n" is noise. It gets the
    // sayable version; the mask is a visual affordance, not information.
    semanticsLabel: '${name.firstName} ${name.lastInitial}',
  );
}

/// Renders a venue's name, in the same reserved register as [PersonName].
///
/// Venue names are catalogue data (OSM), never user input, so this one does
/// take a string — and the type is different from [PersonName]'s on purpose, so
/// that no call site can quietly render a person through the venue path.
class VenueName extends StatelessWidget {
  /// Renders [name] at reading size.
  const VenueName(this.name, {this.hero = false, super.key});

  /// The venue's name as ingested.
  final String name;

  /// Renders at hero size — the meeting point on the reveal screen.
  final bool hero;

  @override
  Widget build(BuildContext context) => Text(
    name,
    style: hero ? ZarType.personNameHero : ZarType.personName,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
