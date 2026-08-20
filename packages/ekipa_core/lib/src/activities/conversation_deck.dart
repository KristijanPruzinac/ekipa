import 'package:ekipa_core/src/activities/activity.dart';
import 'package:ekipa_core/src/foundation/random_source.dart';

/// The zero-equipment default, and the one that has to be excellent.
///
/// **Intention — this is what most hangouts will be**, so the design gets the
/// full argument rather than a shrug.
///
/// **The escalation is the mechanism.** The transcript's instinct was right and
/// it matches the actual finding: closeness between strangers comes from
/// *gradually escalating reciprocal self-disclosure* (Aron et al., 1997, the
/// closeness-generating procedure). So the cards are **sampled but never
/// reordered**, and a minimum gap between intensity levels is enforced.
/// Shuffling destroys the mechanism and can land an intimate question on
/// strangers in minute four.
///
/// **The content is ours.** The canonical 36-question list is an appendix to a
/// copyrighted paper, and being widely republished is not the same as being
/// public domain. We wrote our own on the same published structure — three sets
/// of increasing disclosure, reciprocal turn-taking — and cite the research for
/// the method rather than reproducing the instrument. Cheaper than a licence
/// conversation, and it lets the questions be written for the people who will
/// actually be sitting there.
///
/// **Pass is always available**, on every card, for every person, with no
/// explanation and no visible record. A question deck without a free pass is an
/// interrogation.
final class ConversationDeck implements ActivityTemplate {
  /// Creates the deck.
  const ConversationDeck();

  @override
  String get id => 'CONVERSATION_DECK';

  @override
  String get name => 'Questions';

  @override
  String get brief =>
      'A deck of questions that get slowly more personal. One card at a time, '
      'everyone answers in turn. Anyone can pass on any card, always, with no '
      'explanation.';

  @override
  String get exitScript =>
      'When the last card is done, that is the end. Say “that was the deck — '
      'good to meet you” and go. Nobody has to invent a reason to leave.';

  @override
  String get arrivalScript =>
      'First one there: take a table or a bench where four people can hear '
      'each other, and hold your phone up when you see someone looking round.';

  @override
  ActivityRequirements get requirements => const ActivityRequirements();

  /// How many warm-ups run before the sets begin.
  ///
  /// Three, as the transcript specifies. Their job is to get four people
  /// talking in turn within ninety seconds at no self-disclosure cost — the
  /// hardest ninety seconds of the evening, and the one the deck exists to
  /// carry.
  static const int warmUpCount = 3;

  /// How many cards are drawn from each set.
  static const List<int> perSet = [4, 4, 3];

  @override
  List<ActivityStep> session(RandomSource seed, {required int people}) {
    // Warm-ups are drawn freely: they carry no escalation, so their order
    // carries no meaning, and that freedom is what keeps two consecutive
    // hangouts from opening identically. Drawing without replacement already
    // randomises the order, so there is nothing left to shuffle.
    final warmUps = _sample(seed.fork('warmup'), _warmUps, warmUpCount);

    final steps = <ActivityStep>[
      const ActivityStep(
        text: 'This is a template, not a rule.',
        note:
            'If you end up talking about something else entirely, that '
            'worked. Put the phone down.',
      ),
      for (final question in warmUps)
        ActivityStep(text: question, note: 'Warm-up · everyone answers'),
    ];

    for (final (index, set) in [_setOne, _setTwo, _setThree].indexed) {
      // Sampled, then restored to the source order. This is the whole of the
      // escalation guarantee: within a set the questions still climb, and
      // between sets they climb further.
      final drawn = _sample(seed.fork('set$index'), set, perSet[index])
        ..sort((a, b) => set.indexOf(a).compareTo(set.indexOf(b)));
      for (final question in drawn) {
        steps.add(
          ActivityStep(
            text: question,
            note: '${_setNames[index]} · everyone answers, in turn',
            intensity: index + 1,
          ),
        );
      }
    }

    steps.add(
      ActivityStep(
        text: 'That is the deck.',
        note: people >= 4
            ? 'Four people who did not know each other an hour ago. That is '
                  'the whole thing. Ratings arrive shortly.'
            : 'Three people who did not know each other an hour ago. That '
                  'is the whole thing. Ratings arrive shortly.',
      ),
    );
    return List.unmodifiable(steps);
  }

  static const List<String> _setNames = ['Set one', 'Set two', 'Set three'];

  List<T> _sample<T>(RandomSource source, List<T> pool, int count) {
    final remaining = [...pool];
    final drawn = <T>[];
    for (var i = 0; i < count && remaining.isNotEmpty; i++) {
      drawn.add(remaining.removeAt(source.nextInt(remaining.length)));
    }
    return drawn;
  }

  // ── The content ────────────────────────────────────────────────────────────
  //
  // Written for people in their twenties who have just sat down with strangers
  // in a Croatian city. Three properties every question here has to have:
  // answerable in under a minute, answerable by someone having a bad week, and
  // not answerable with one word.

  static const List<String> _warmUps = [
    'What did you eat today that you would happily eat again tomorrow?',
    'Which part of town do you know best, and how did that happen?',
    'What are you mildly, unreasonably good at?',
    'What were you doing an hour before this?',
    'What is the last thing that made you laugh out loud?',
    'Morning or late night — pick one and defend it in a sentence.',
    'What did you want to be when you were nine?',
    'What is a small thing that makes a day worse than it needs to be?',
    'Name one thing about this place you would change.',
    'What is the last song you played twice in a row?',
    'Free Tuesday afternoon, no obligations. Where do you go?',
    'What is something you have been meaning to do for months?',
  ];

  static const List<String> _setOne = [
    'What did you change your mind about in the last year?',
    'What do people usually get wrong about you when they first meet you?',
    'What is the best thing anyone has ever taught you?',
    'Describe a perfect ordinary day. Not a holiday — a Tuesday.',
    'What do you own that you would genuinely be sad to lose?',
    'What do you do that your friends find strange?',
    'What did your family do that you thought everyone did?',
    'If you could keep only one thing you are good at, which one?',
    'What is the longest you spent on something nobody asked for?',
    'What is a compliment you never know how to accept?',
    'Where do you go when you want to not be found?',
    'What are you looking forward to that nobody else would care about?',
  ];

  static const List<String> _setTwo = [
    'What is a decision you made that changed the shape of your life?',
    'Who do you most want to be proud of you, and why them?',
    'What were you certain about at eighteen and are not now?',
    'Is there a friendship you lost that you still think about?',
    'What do you do when you are the most alone you get?',
    'What is a rule you were raised with that you have decided to keep?',
    'When did you last feel completely out of your depth, and what happened?',
    'What is the kindest thing a stranger has ever done for you?',
    'What do you want more of that you find embarrassing to ask for?',
    'Go round: tell each person something you noticed about them tonight.',
    'What is something you are quietly proud of that never comes up?',
    'What is the last thing that moved you — a film, a person, a song?',
  ];

  static const List<String> _setThree = [
    'If you knew you had a year, what would you change about now?',
    'What should a close friend know about you before they get close?',
    'Tell the group about a time you were badly wrong about someone.',
    'What is one thing you would ask for help with, if asking were free?',
    'What part of yourself have you made peace with?',
    'Share a problem you actually have. Ask the others what they would do.',
    'What do you do when you are sad that you would rather nobody knew?',
    'What are you still angry about?',
    'When did you last feel at ease with people you barely knew?',
    'Go round: tell each person what you want them to remember of tonight.',
    'What do you most hope is true about your life in five years?',
  ];
}
