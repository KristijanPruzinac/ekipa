import 'package:ekipa_core/src/activities/activity.dart';
import 'package:ekipa_core/src/foundation/random_source.dart';

/// Bring a deck.
///
/// The transcript's reasoning is right and is preserved verbatim because the
/// number in it is load-bearing: *"we need at least 2 people with cards in a
/// normal card game meet, because one can dip."*
///
/// **`minCarriers = 2` is a matchmaker constraint, not a hope.** A person's
/// profile carries what they can bring, the assembler will not emit a `CARDS`
/// hangout without two carriers, and a backfill that drops below two carriers
/// **switches the activity** to `CONVERSATION_DECK` and tells everyone at
/// reveal — rather than sending four people to play nothing.
///
/// The other dead end this has to survive is *"we have cards and nobody knows a
/// four-player game"*, which is why the session is a rule card rather than a
/// list of suggestions. Three games, all playable on a bench, all findable in
/// Croatia: Briškula in pairs, Šnaps, and Presjednik for a group that wants
/// noise.
final class CardsActivity implements ActivityTemplate {
  /// Creates the activity.
  const CardsActivity();

  @override
  String get id => 'CARDS';

  @override
  String get name => 'Cards';

  @override
  String get brief =>
      'Two of you are bringing a deck. Pick one of the games on the card and '
      'play. Nobody has to be good at it.';

  @override
  String get exitScript =>
      'End on a finished hand, not mid-game. Say “last one” before you deal '
      'it, so everybody knows where the end is.';

  @override
  String get arrivalScript =>
      'First one there: find a flat surface four people can reach — a table, a '
      'wide ledge, the top of a bag on a bench.';

  @override
  ActivityRequirements get requirements => const ActivityRequirements(
    equipment: 'deck_of_cards',
    minCarriers: 2,
    needsSeating: true,
  );

  @override
  List<ActivityStep> session(RandomSource seed, {required int people}) {
    // Deterministic per hangout, like every session: the same group opening the
    // app twice gets the same suggested game rather than a new opinion.
    final games = people >= 4 ? _forFour : _forThree;
    final first = games[seed.fork('game').nextInt(games.length)];
    return List.unmodifiable([
      const ActivityStep(
        text: 'Whoever brought a deck, get it out.',
        note:
            'Two of you said you would. If neither did, say so now and switch '
            'to talking — nobody minds, and the app will not hold it against '
            'the evening.',
      ),
      ActivityStep(text: first.$1, note: first.$2),
      for (final game in games.where((candidate) => candidate != first))
        ActivityStep(text: game.$1, note: game.$2, intensity: 1),
      const ActivityStep(
        text: 'Last hand.',
        note: 'Say it out loud before you deal it. Then that is the evening.',
      ),
    ]);
  }

  static const List<(String, String)> _forFour = [
    (
      'Briškula, in pairs',
      'Partners sit opposite. Trump suit is turned up, follow suit is not '
          'required, highest trump takes it. Two rounds and everyone has the '
          'hang of it.',
    ),
    (
      'Šnaps, in pairs',
      'Same partners, but you are counting to sixty-six. Slower, better for '
          'talking over.',
    ),
    (
      'Presjednik',
      'Everyone for themselves, shed your hand, last one out deals next. Loud, '
          'easy, and nobody has to concentrate.',
    ),
  ];

  static const List<(String, String)> _forThree = [
    (
      'Presjednik',
      'Everyone for themselves, shed your hand, last one out deals next. Works '
          'perfectly with three.',
    ),
    (
      'Briškula, three-handed',
      'Take one card out of the deck so it divides. Otherwise as usual: trump '
          'is turned up, highest trump takes it.',
    ),
  ];
}
