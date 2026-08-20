import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/member_gateway.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/screens/availability.dart';
import 'package:mobile/src/screens/confirm.dart';
import 'package:mobile/src/screens/home.dart';
import 'package:mobile/src/screens/live.dart';
import 'package:mobile/src/screens/onboarding.dart';
import 'package:mobile/src/screens/rate.dart';
import 'package:mobile/src/screens/reveal.dart';
import 'package:mobile/src/screens/sign_in.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:mobile/src/widgets/async_block.dart';

/// Decides which screen is on.
///
/// **This is the route guard, and it guards nothing.** It reads
/// [memberStateProvider] and each hangout's `phase` — both server answers — and
/// renders accordingly. It is a *display* decision. Every actual gate is in
/// Postgres: a suspended person who patched this file into showing the picker
/// would reach `set_availability` and be refused by a policy, not by a screen
/// (`11_SECURITY.md §2`).
///
/// Saying so out loud matters, because a guard that looks like enforcement is
/// how the real check quietly stops being written.
class AppShell extends ConsumerStatefulWidget {
  /// The shell.
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Where onboarding has got to.
enum _Step {
  /// Not verified.
  signIn,

  /// Which gender.
  gender,

  /// Whether they can bring a deck.
  equipment,

  /// Where they set out from.
  neighbourhood,
}

/// What the shell is showing once somebody is active.
enum _View {
  /// The one-instruction home.
  home,

  /// The calendar.
  availability,

  /// Whatever the next hangout needs.
  hangout,
}

class _AppShellState extends ConsumerState<AppShell> {
  _Step _step = _Step.signIn;
  _View _view = _View.home;
  bool _busy = false;
  String? _failure;

  Future<void> _finishSignup() async {
    final draft = ref.read(onboardingProvider);
    if (!draft.isComplete) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(gatewayProvider)
          .createProfile(
            firstName: draft.firstName,
            lastInitial: draft.lastInitial,
            genderCode: draft.genderCode!,
            // The anchor is optional, so a declined location sends the city
            // centre and the server treats it as "no useful anchor". Sending
            // nothing at all would make the column nullable everywhere
            // downstream for the sake of a case the matcher already handles as
            // "no reachable cluster".
            anchorLatitude: draft.anchorLatitude ?? 0,
            anchorLongitude: draft.anchorLongitude ?? 0,
            equipment: draft.equipment,
          );
      ref
        ..invalidate(memberStateProvider)
        ..invalidate(profileProvider);
    } on MemberFailure catch (failure) {
      setState(() => _failure = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberStateProvider);

    return AsyncBlock<MemberState>(
      value: state,
      builder: (member) => switch (member) {
        MemberState.banned || MemberState.suspended => const SuspendedScreen(),
        MemberState.incomplete => _onboarding(),
        MemberState.active => _active(),
      },
    );
  }

  Widget _onboarding() => switch (_step) {
    _Step.signIn => SignInScreen(
      onVerified: (identity) {
        ref.read(onboardingProvider.notifier).beginWith(identity);
        setState(() => _step = _Step.gender);
      },
    ),
    _Step.gender => GenderStep(
      onNext: () => setState(() => _step = _Step.equipment),
    ),
    _Step.equipment => EquipmentStep(
      onNext: () => setState(() => _step = _Step.neighbourhood),
    ),
    _Step.neighbourhood => NeighbourhoodStep(
      busy: _busy,
      failure: _failure,
      onFinish: _finishSignup,
    ),
  };

  Widget _active() {
    final next = ref.watch(nextHangoutProvider).value;

    return switch (_view) {
      _View.availability => AvailabilityScreen(
        onDone: () => setState(() => _view = _View.home),
      ),
      _View.hangout when next != null => _forHangout(next),
      _ => HomeScreen(
        onEditAvailability: () => setState(() => _view = _View.availability),
        onOpenHangout: (_) => setState(() => _view = _View.hangout),
      ),
    };
  }

  /// The hangout's own phase decides the screen, not a stored route.
  ///
  /// A route that outlived the phase is how somebody ends up on a confirmation
  /// screen for a hangout that locked ten minutes ago. Deriving it every build
  /// from the server's answer makes that impossible rather than unlikely.
  Widget _forHangout(Hangout hangout) => switch (hangout.phase) {
    HangoutPhase.confirming || HangoutPhase.backfilling => ConfirmScreen(
      hangout: hangout,
      onAnswered: ({required coming}) => setState(() => _view = _View.home),
    ),
    HangoutPhase.revealed => RevealScreen(
      hangout: hangout,
      onArrived: () async {
        await ref.read(gatewayProvider).markArrived(hangout.id);
        ref.invalidate(hangoutsProvider);
      },
    ),
    HangoutPhase.live => LiveScreen(hangout: hangout),
    HangoutPhase.rating => RateScreen(
      hangout: hangout,
      onDone: () => setState(() => _view = _View.home),
    ),
    _ => HomeScreen(
      onEditAvailability: () => setState(() => _view = _View.availability),
    ),
  };
}
