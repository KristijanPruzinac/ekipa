import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'data/mock_data.dart';
import 'data/profile_status.dart';
import 'data/supabase_client.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/invite_detail_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reflect_screen.dart';
import 'screens/welcome_screen.dart';

/// Calm fade-through + a whisper of scale, so screens dissolve into one
/// another instead of cutting. Kept gentle on purpose — motion here is
/// atmosphere, not spectacle.
CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: Transform.scale(
          scale: 0.98 + 0.02 * eased.value,
          child: child,
        ),
      );
    },
  );
}

Meetup _mockMeetupById(String id) => switch (id) {
      _ when id == mockStanding.id => mockStanding,
      _ when id == mockFormingConfirmed.id => mockFormingConfirmed,
      _ => mockMeetup,
    };

/// Bridges Supabase's auth stream to GoRouter's `refreshListenable`, so a
/// sign-in/sign-out re-evaluates `redirect` without a manual navigation
/// call. Only ever constructed when a backend is actually configured — see
/// [_authListenable] below — so it never touches an uninitialized client.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = supabase.auth.onAuthStateChange.listen((_) {
      // A sign-out must forget the cached onboarding state, or the next user
      // on this device inherits the previous one's "already onboarded" answer.
      if (supabase.auth.currentSession == null) profileStatus.invalidate();
      notifyListeners();
    });
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authListenable = isBackendConfigured ? _AuthChangeNotifier() : null;

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authListenable,
  redirect: (context, state) async {
    // Without a configured backend the app runs entirely on mock data (see
    // README) — no auth gate, straight to Welcome, unchanged from before.
    if (!isBackendConfigured) return null;

    final loggedIn = supabase.auth.currentSession != null;
    final loc = state.matchedLocation;
    if (!loggedIn) return loc == '/auth' ? null : '/auth';
    if (loc == '/auth') return '/';

    // Signed in: gate on the one-time logistics onboarding. The result is
    // cached (see ProfileStatus), so this isn't a per-navigation round-trip.
    final onboarded = await profileStatus.isComplete();
    if (!onboarded) return loc == '/onboarding' ? null : '/onboarding';
    if (loc == '/onboarding') return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => _fade(const AuthScreen(), state),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => _fade(
        OnboardingScreen(onDone: () => context.go('/')),
        state,
      ),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _fade(
        WelcomeScreen(onContinue: () => context.push('/home')),
        state,
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _fade(
        HomeScreen(
          onOpenMeetup: (meetup) => context.push('/invite/${meetup.id}', extra: meetup),
        ),
        state,
      ),
    ),
    GoRoute(
      path: '/invite/:id',
      pageBuilder: (context, state) {
        final meetup = (state.extra as Meetup?) ?? _mockMeetupById(state.pathParameters['id']!);
        return _fade(
          InviteDetailScreen(
            meetup: meetup,
            onAccept: () => context.go('/home'),
            onDecline: () => context.pop(),
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/reflect/:id',
      pageBuilder: (context, state) {
        final meetup = (state.extra as Meetup?) ?? _mockMeetupById(state.pathParameters['id']!);
        return _fade(
          ReflectScreen(meetup: meetup, onDone: () => context.go('/home')),
          state,
        );
      },
    ),
  ],
);
