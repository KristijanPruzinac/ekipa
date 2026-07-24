import 'package:go_router/go_router.dart';
import 'data/mock_data.dart';
import 'models/models.dart';
import 'screens/home_screen.dart';
import 'screens/invite_detail_screen.dart';
import 'screens/reflect_screen.dart';
import 'screens/welcome_screen.dart';

Meetup _meetupById(String id) => id == mockStanding.id ? mockStanding : mockMeetup;

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => WelcomeScreen(
        onContinue: () => context.push('/home'),
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(
        onOpenMeetup: (meetup) => context.push('/invite/${meetup.id}'),
      ),
    ),
    GoRoute(
      path: '/invite/:id',
      builder: (context, state) {
        final meetup = _meetupById(state.pathParameters['id']!);
        return InviteDetailScreen(
          meetup: meetup,
          onAccept: () => context.pushReplacement('/reflect/preview'),
          onDecline: () => context.pop(),
        );
      },
    ),
    GoRoute(
      path: '/reflect/:id',
      builder: (context, state) => ReflectScreen(
        onDone: () => context.go('/home'),
      ),
    ),
  ],
);
