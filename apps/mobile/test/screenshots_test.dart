/// Renders every screen to a PNG.
///
/// **Intention — a picture of the app that cannot be out of date.** These are
/// not mock-ups: each file is the real widget tree, laid out by the real
/// engine, with the real fonts and the real Osijek basemap. A screen that
/// changes and a picture that does not is a failing build.
///
/// They double as regression goldens once the screens settle. Until then their
/// job is to be *looked at*, which is why they are phone-shaped and named in
/// the order somebody meets them. Three visual bugs in the first version of
/// this app — a word broken mid-line, a hollow square where an icon should
/// have been, straight quotes in body copy — were found here and by nothing
/// else, because reading code does not show you a rendered line break.
///
/// Run with `--update-goldens` to refresh.
library;

import 'dart:io';

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/testing.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/data/rehearsal_gateway.dart';
import 'package:mobile/src/identity/name_only_verifier.dart';
import 'package:mobile/src/screens/availability.dart';
import 'package:mobile/src/screens/confirm.dart';
import 'package:mobile/src/screens/home.dart';
import 'package:mobile/src/screens/live.dart';
import 'package:mobile/src/screens/onboarding.dart';
import 'package:mobile/src/screens/rate.dart';
import 'package:mobile/src/screens/reveal.dart';
import 'package:mobile/src/screens/sign_in.dart';
import 'package:mobile/src/state/providers.dart';

/// A Thursday in term time, so the picker's first evening is tomorrow.
final DateTime testNow = DateTime.utc(2026, 10, 20, 9);

void main() {
  // Both of these read files, and **both must happen out here**. A
  // `testWidgets` body runs inside a fake-async zone, where a real
  // `File.readAsBytes()` completes on the real event loop and its result is
  // never delivered — the test simply stops, with no error and no output. Cost
  // of learning that: one fourteen-minute run of nothing.
  setUpAll(() async {
    await loadZarFonts();
    await _loadBasemap();
  });

  testWidgets('01 sign in', (tester) async {
    await _shoot(
      tester,
      '01_sign_in',
      Rehearsal.fresh,
      (_) => SignInScreen(onVerified: (_) {}),
    );
  });

  testWidgets('02 gender', (tester) async {
    await _shoot(
      tester,
      '02_gender',
      Rehearsal.fresh,
      (_) => GenderStep(onNext: () {}),
    );
  });

  testWidgets('03 equipment', (tester) async {
    await _shoot(
      tester,
      '03_equipment',
      Rehearsal.fresh,
      (_) => EquipmentStep(onNext: () {}),
    );
  });

  testWidgets('04 where you set out from', (tester) async {
    await _shoot(
      tester,
      '04_anchor',
      Rehearsal.fresh,
      (_) => NeighbourhoodStep(busy: false, onFinish: () {}),
    );
  });

  testWidgets('05 the calendar, empty', (tester) async {
    await _shoot(
      tester,
      '05_calendar',
      Rehearsal.waiting,
      (_) => const AvailabilityScreen(),
      tall: 2200,
    );
  });

  testWidgets('06 the calendar, a day open', (tester) async {
    await _shoot(
      tester,
      '06_calendar_day',
      Rehearsal.waiting,
      (_) => const AvailabilityScreen(),
      tall: 2200,
      after: (tester) async {
        // `.first` because the picker shows six weeks, which spans two months,
        // and a 23rd falls in both. The first is October's — a Friday, so a
        // live cell — and the second is November's, drawn faint.
        await tester.tap(find.text('23').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('17:30'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('07 home, quiet', (tester) async {
    await _shoot(
      tester,
      '07_home_quiet',
      Rehearsal.waiting,
      (_) => const HomeScreen(),
    );
  });

  testWidgets('08 home, tonight', (tester) async {
    await _shoot(
      tester,
      '08_home_tonight',
      Rehearsal.revealed,
      (_) => const HomeScreen(),
    );
  });

  testWidgets('09 the morning-of confirmation', (tester) async {
    await _shoot(
      tester,
      '09_confirm',
      Rehearsal.confirming,
      (hangout) => ConfirmScreen(hangout: hangout!),
      tall: 2400,
    );
  });

  testWidgets('10 the reveal', (tester) async {
    await _shoot(
      tester,
      '10_reveal',
      Rehearsal.revealed,
      (hangout) => RevealScreen(hangout: hangout!, onArrived: () {}),
      tall: 4600,
    );
  });

  testWidgets('11 arriving', (tester) async {
    await _shoot(
      tester,
      '11_arriving',
      Rehearsal.arriving,
      (hangout) => LiveScreen(hangout: hangout!),
    );
  });

  testWidgets('12 the deck', (tester) async {
    await _shoot(
      tester,
      '12_deck',
      Rehearsal.playing,
      (hangout) => LiveScreen(hangout: hangout!),
    );
  });

  testWidgets('13 rating', (tester) async {
    await _shoot(
      tester,
      '13_rating',
      Rehearsal.rating,
      (hangout) => RateScreen(hangout: hangout!),
      tall: 5200,
    );
  });

  testWidgets('14 suspended', (tester) async {
    await _shoot(
      tester,
      '14_suspended',
      Rehearsal.suspended,
      (_) => const SuspendedScreen(),
    );
  });

  testWidgets('15 the sigil set', (tester) async {
    await _shootRaw(tester, '15_sigils', const _SigilSheet(), height: 1500);
  });
}

/// Pumps a screen against a rehearsal server in [stage] and writes its golden.
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Rehearsal stage,
  Widget Function(Hangout? hangout) build, {
  double tall = 1704,
  Future<void> Function(WidgetTester tester)? after,
}) async {
  final gateway = RehearsalGateway(FakeClock(testNow), stage);
  final hangouts = await gateway.hangouts();
  final basemap = _cached;

  await _shootRaw(
    tester,
    name,
    ProviderScope(
      overrides: [
        gatewayProvider.overrideWithValue(gateway),
        verifierProvider.overrideWithValue(const NameOnlyVerifier()),
        clockProvider.overrideWithValue(FakeClock(testNow)),
        basemapProvider.overrideWith((ref) async => basemap),
      ],
      child: build(hangouts.isEmpty ? null : hangouts.first),
    ),
    height: tall,
    after: after,
  );
}

Future<void> _shootRaw(
  WidgetTester tester,
  String name,
  Widget child, {
  double height = 1704,
  Future<void> Function(WidgetTester tester)? after,
}) async {
  // A Pixel-ish width. The design system caps content at 560, so this is the
  // width every measurement in it was chosen against. Height is per-screen and
  // deliberately generous: a golden is for looking at, and a screen cut off at
  // the fold hides exactly the parts nobody has reviewed.
  tester.view
    ..physicalSize = Size(786, height)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: EkipaTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
  if (after != null) await after(tester);
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// The whole sigil catalogue, so all twenty-four drawings get looked at.
///
/// Twenty-four hand-drawn paths is exactly the kind of thing that is 90% right
/// and 10% quietly wrong, and the only way to find the 10% is to see them
/// together at the size people will see them.
class _SigilSheet extends StatelessWidget {
  const _SigilSheet();

  static const List<String> _symbols = [
    'circle',
    'square',
    'triangle',
    'diamond',
    'star',
    'heart',
    'sun',
    'moon',
    'cloud',
    'bolt',
    'drop',
    'wave',
    'leaf',
    'flower',
    'tree',
    'mountain',
    'feather',
    'shell',
    'key',
    'anchor',
    'bell',
    'arrow',
    'flame',
    'bird',
  ];

  static const List<String> _colours = [
    'red',
    'orange',
    'yellow',
    'green',
    'blue',
    'purple',
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ZarColors.ground,
    child: Padding(
      padding: const EdgeInsets.all(ZarSpace.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The sigil set', style: ZarType.title),
            const SizedBox(height: ZarSpace.xs),
            Text(
              '24 symbols × 6 colours. Two groups never share one at the same '
              'place in the same window — a database constraint, not a hope.',
              style: ZarType.body.copyWith(color: ZarColors.inkMuted),
            ),
            const SizedBox(height: ZarSpace.xl),
            Wrap(
              spacing: ZarSpace.md,
              runSpacing: ZarSpace.md,
              children: [
                for (final (index, symbol) in _symbols.indexed)
                  Sigil(
                    symbol: symbol,
                    colour: _colours[index % _colours.length],
                    size: 54,
                  ),
              ],
            ),
            const SizedBox(height: ZarSpace.xxl),
            const Text('Every colour, one symbol', style: ZarType.heading),
            const SizedBox(height: ZarSpace.md),
            Wrap(
              spacing: ZarSpace.md,
              runSpacing: ZarSpace.md,
              children: [
                for (final colour in _colours)
                  Sigil(symbol: 'key', colour: colour, size: 54, label: colour),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Basemap? _cached;

Future<void> _loadBasemap() async {
  final file = File('assets/basemap/osijek.ekmap');
  if (!file.existsSync()) return;
  _cached = Basemap.decode(await file.readAsBytes()).valueOrNull;
}

/// Loads the real faces, so these are pictures of the app rather than of boxes.
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
