/// How a console screen is put on a test surface.
///
/// **Intention — one place binds the ports, so no test can forget to.** The
/// composition root overrides `gatewayProvider` and `clockProvider` and nothing
/// else; this does the same, with a fake and a stopped clock. A screen that
/// starts reading a third port will fail here rather than quietly reaching for
/// a default.
///
/// **The surface is 1280x900 on purpose.** The console is a desktop browser
/// tool with a 232px rail and four-column tables; the 800x600 default that
/// `flutter_test` gives you is a phone, and a table that overflows only at
/// phone width would fail every test for a reason that never happens in
/// production.
library;

import 'dart:io';

import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/state/providers.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:ekipa_core/testing.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The instant every fixture in this suite is written around.
///
/// A Tuesday morning in the week Croatia leaves summer time, because two of the
/// things worth testing — a scheduled version that is not yet live, and a slot
/// table that crosses the DST boundary — are both easiest to state from here.
final DateTime testNow = DateTime.utc(2026, 10, 20, 9);

/// Loads the real faces into the test binary.
///
/// Without this every glyph is a filled box of the wrong width, and a console
/// full of tables measured against fake metrics can report an overflow that
/// does not exist — or, worse, miss one that does. The files are read from
/// `ekipa_ui` directly rather than through the asset bundle, because a test
/// binary has no bundle.
///
/// *Rejected — skipping it and pretending layout assertions are cheap.* The
/// rail was 60px over in exactly this way, and only a real measurement said so.
Future<void> loadZarFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = {
    'Archivo': [
      'Archivo-Regular.ttf',
      'Archivo-Medium.ttf',
      'Archivo-SemiBold.ttf',
      'Archivo-Bold.ttf',
    ],
    'Instrument Serif': ['InstrumentSerif-Regular.ttf'],
    'DM Mono': ['DMMono-Regular.ttf', 'DMMono-Medium.ttf'],
  };

  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader('packages/ekipa_ui/$family');
    for (final file in files) {
      final bytes = await File(
        '../../packages/ekipa_ui/fonts/$file',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Pumps [screen] with the ports bound to [gateway] and a stopped clock.
Future<void> pumpConsole(
  WidgetTester tester,
  Widget screen, {
  required ConsoleGateway gateway,
  DateTime? now,
  Size size = const Size(1280, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gatewayProvider.overrideWithValue(gateway),
        clockProvider.overrideWithValue(FakeClock(now ?? testNow)),
      ],
      child: MaterialApp(
        theme: ConsoleTheme.dark(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: ZarColors.ground, body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
