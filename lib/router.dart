import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'data/mock_data.dart';
import 'data/supabase_client.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/invite_detail_screen.dart';
import 'screens/reflect_screen.dart';
import 'screens/welcome_screen.dart';

Meetup _mockMeetupById(String id) => id == mockStanding.id ? mockStanding : mockMeetup;

/// Bridges Supabase's auth stream to GoRouter's `refreshListenable`, so a
/// sign-in/sign-out re-evaluates `redirect` without a manual navigation
/// call. Only ever constructed when a backend is actually configured — see
/// [_authListenable] below — so it never touches an uninitialized client.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
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
  redirect: (context, state) {
    // Without a configured backend the app runs entirely on mock data (see
    // README) — no auth gate, straight to Welcome, unchanged from before.
    if (!isBackendConfigured) return null;

    final loggedIn = supabase.auth.currentSession != null;
    final onAuthScreen = state.matchedLocation == '/auth';
    if (!loggedIn) return onAuthScreen ? null : '/auth';
    if (loggedIn && onAuthScreen) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => WelcomeScreen(
        onContinue: () => context.push('/home'),
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(
        onOpenMeetup: (meetup) => context.push('/invite/${meetup.id}', extra: meetup),
      ),
    ),
    GoRoute(
      path: '/invite/:id',
      builder: (context, state) {
        final meetup = (state.extra as Meetup?) ?? _mockMeetupById(state.pathParameters['id']!);
        return InviteDetailScreen(
          meetup: meetup,
          onAccept: () => context.pushReplacement('/reflect/${meetup.id}', extra: meetup),
          onDecline: () => context.pop(),
        );
      },
    ),
    GoRoute(
      path: '/reflect/:id',
      builder: (context, state) {
        final meetup = (state.extra as Meetup?) ?? mockMeetup;
        return ReflectScreen(
          meetup: meetup,
          onDone: () => context.go('/home'),
        );
      },
    ),
  ],
);
