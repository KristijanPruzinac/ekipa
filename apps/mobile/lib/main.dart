import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_data/ekipa_data.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/member_gateway.dart';
import 'package:mobile/src/data/rehearsal_gateway.dart';
import 'package:mobile/src/data/supabase_gateway.dart';
import 'package:mobile/src/identity/name_only_verifier.dart';
import 'package:mobile/src/shell.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Composition root for the mobile app.
///
/// The app is a thin cache over server truth and owns no rules: every privacy
/// and trust decision is made server-side and rendered here
/// (`docs/v3/11_SECURITY.md` §2).
///
/// Note what is *not* imported: `package:ekipa_core/matching.dart`. Directive
/// D9 keeps the matcher out of every user build, and `tools/lint` fails the
/// build if it ever appears here.
///
/// **Four ports are bound here and nowhere else.** All four throw when nothing
/// overrides them, so a screen that ends up in a test without a fake fails by
/// name rather than reaching the network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gateway = await _connect();

  runApp(
    ProviderScope(
      overrides: [
        gatewayProvider.overrideWithValue(gateway),
        // Still a placeholder, and still one line. AAI@EduHr replaces this
        // expression and nothing else in the app changes — which is the whole
        // point of binding the ports in one place.
        verifierProvider.overrideWithValue(const NameOnlyVerifier()),
        clockProvider.overrideWithValue(const SystemClock()),
        basemapProvider.overrideWith((ref) => loadBasemap()),
      ],
      child: const EkipaApp(),
    ),
  );
}

/// The project URL, compiled in.
const String _url = String.fromEnvironment('SUPABASE_URL');

/// The **publishable** key, compiled in.
///
/// **This is the only key that may ever appear in a Flutter build.** It grants
/// nothing on its own: every table is behind RLS and every RPC checks the
/// caller, so a key extracted from an APK — which takes about a minute — is
/// worth exactly what an anonymous session is worth. The service-role key
/// bypasses all of that and lives in one place, the worker's secret manager
/// (`11_SECURITY.md` §4). `tools/lint` fails the build if it appears in a
/// `--dart-define`.
const String _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Opens the session, falling back to the rehearsal script.
///
/// **The fallback is a build-time fact, not a runtime retry.** With no URL
/// compiled in, this is a demo build and the scripted gateway is the honest
/// answer. With a URL compiled in and the network down, it is the real app
/// having a bad moment, and it must say so through the normal failure path
/// rather than quietly showing somebody a fictional hangout — a person who
/// walked to a café because a fake told them to would be right to never open
/// this again.
Future<MemberGateway> _connect() async {
  if (_url.isEmpty || _key.isEmpty) {
    return RehearsalGateway(const SystemClock(), Rehearsal.revealed);
  }

  await Supabase.initialize(url: _url, publishableKey: _key);
  final client = Supabase.instance.client;

  // **An anonymous auth user, on purpose.** The university address never
  // reaches `auth.users`: the verifier hands its result to the worker, which
  // stores a peppered hash and links it to whatever anonymous user the phone is
  // holding (`0002_v3_people.sql`). So the session identifies a *device's
  // claim*, and the identity behind it is a hash nobody can reverse — including
  // us, because the pepper is in a KMS and not in Postgres.
  if (client.auth.currentSession == null) {
    await client.auth.signInAnonymously();
  }

  return SupabaseGateway(client);
}

/// Reads the city's geometry off disk.
///
/// **Returns `null` rather than throwing.** A missing or corrupt basemap costs
/// the map, not the screen the map is on — the address and the standing spot
/// are the answer, and the map is context. An asset failure at reveal time
/// would otherwise be a black screen at the exact moment somebody needs to know
/// where to walk.
Future<Basemap?> loadBasemap() async {
  try {
    final bytes = await rootBundle.load('assets/basemap/osijek.ekmap');
    final decoded = Basemap.decode(bytes.buffer.asUint8List());
    return decoded.valueOrNull;
  } on Object {
    return null;
  }
}

/// The application shell.
class EkipaApp extends StatelessWidget {
  /// Creates the shell.
  const EkipaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ekipa',
    debugShowCheckedModeBanner: false,
    theme: EkipaTheme.dark(),
    home: const AppShell(),
  );
}
