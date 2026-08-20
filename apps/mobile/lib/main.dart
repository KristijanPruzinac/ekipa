import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_data/ekipa_data.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/rehearsal_gateway.dart';
import 'package:mobile/src/identity/name_only_verifier.dart';
import 'package:mobile/src/shell.dart';
import 'package:mobile/src/state/providers.dart';

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
void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Two of these are placeholders, and both are one line. That is the
        // whole point of the ports: the AAI verifier and the Supabase gateway
        // replace these two expressions and nothing else in the app changes.
        gatewayProvider.overrideWithValue(
          RehearsalGateway(const SystemClock(), Rehearsal.revealed),
        ),
        verifierProvider.overrideWithValue(const NameOnlyVerifier()),
        clockProvider.overrideWithValue(const SystemClock()),
        basemapProvider.overrideWith((ref) => loadBasemap()),
      ],
      child: const EkipaApp(),
    ),
  );
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
