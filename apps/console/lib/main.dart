import 'package:console/src/data/supabase_gateway.dart';
import 'package:console/src/screens/sign_in.dart';
import 'package:console/src/state/providers.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:console/src/widgets/console_shell.dart';
import 'package:ekipa_data/ekipa_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Composition root for the master console.
///
/// Zone 1.5 in the trust model: separate app, separate deployment, MFA
/// required. It holds **no service-role key** — every read and write is an
/// audited RPC that re-checks the caller's role server-side (AC-4). The only
/// credential in this build is the publishable anon key, which grants nothing
/// on its own: migration 0009 revokes every console function from `anon`.
///
/// It is also pseudonymous by default: the audit trail shows `OP-7F3A`, never a
/// name, and the console has no view over people at all (`12_CONSOLE.md` §2).
///
/// **The two ports are bound here and nowhere else.** `gatewayProvider` and
/// `clockProvider` both throw if nothing overrides them, so a screen that ends
/// up in a test without a fake fails loudly rather than reaching the network.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    // Publishable, and safe in a browser bundle by design. If a key with more
    // than this ever appears in a `--dart-define`, `tools/lint` fails the
    // build: see `CONSOLE-NO-SERVICE-KEY`.
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  runApp(
    ProviderScope(
      overrides: [
        gatewayProvider.overrideWithValue(
          SupabaseConsoleGateway(Supabase.instance.client),
        ),
        clockProvider.overrideWithValue(const SystemClock()),
      ],
      child: const ConsoleApp(),
    ),
  );
}

/// The console shell.
class ConsoleApp extends StatelessWidget {
  /// Creates the shell.
  const ConsoleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ekipa console',
    debugShowCheckedModeBanner: false,
    theme: ConsoleTheme.dark(),
    home: const _AuthGate(),
  );
}

/// Signed in, or not.
///
/// Watches the auth stream rather than reading the session once: a token that
/// expires mid-session should return the operator to the sign-in screen, not
/// leave them looking at a console where every panel has quietly become a
/// refusal.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final auth = Supabase.instance.client.auth;
      final session = snapshot.data?.session ?? auth.currentSession;
      return session == null ? const SignInScreen() : const ConsoleShell();
    },
  );
}
