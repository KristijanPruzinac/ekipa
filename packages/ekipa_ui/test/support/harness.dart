import 'dart:io';

import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled faces into the test binary.
///
/// `flutter test` renders every glyph as a filled box unless real fonts are
/// registered, which makes a widget test unable to say anything about text
/// layout — wrapping, overflow, whether a fact strip still fits at 200% text
/// scale. Those are the failures worth catching here, so the fonts are loaded.
///
/// *Rejected — the `golden_toolkit` package's `loadAppFonts()`:* one more
/// dependency (SC-2) for twenty lines that read the same files.
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
    // The family name the engine sees for a packaged font is prefixed, exactly
    // as TextStyle(package:) resolves it.
    final loader = FontLoader('packages/ekipa_ui/$family');
    for (final file in files) {
      final bytes = await File('fonts/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Wraps [child] in the app's theme.
///
/// Every primitive test goes through this, so a primitive that only looks right
/// inside some particular screen's scaffolding fails here rather than in the
/// app.
Widget harness(
  Widget child, {
  double textScale = 1,
  bool reduceMotion = false,
}) => MediaQuery(
  data: MediaQueryData(
    textScaler: TextScaler.linear(textScale),
    disableAnimations: reduceMotion,
  ),
  child: MaterialApp(
    theme: EkipaTheme.dark(),
    debugShowCheckedModeBanner: false,
    home: child,
  ),
);

/// Runs [body] with the test surface set to [size], then restores it.
///
/// `MediaQuery(size:)` alone does **not** resize the render surface. The
/// widget under test still lays out against the 800x600 default, so a test
/// claiming "the button is still on screen at 360x480" would pass on a
/// viewport twice the height it named. This is the version that resizes.
Future<void> onSurface(
  WidgetTester tester,
  Size size,
  Future<void> Function() body,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await body();
}
