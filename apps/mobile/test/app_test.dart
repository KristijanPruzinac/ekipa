/// The composition root, and the one rule the shell must obey.
///
/// **Intention — lock the two claims `main.dart` makes about itself.** It says
/// four ports are bound in one place and that an unbound one fails by name
/// rather than reaching the network; and it says the shell renders what the
/// server decided rather than deciding anything. Both are load-bearing and both
/// are the kind of claim that quietly stops being true — a convenience default
/// added to a provider, a local `bool` added to the shell — with nothing going
/// red. These tests go red.
library;

import 'package:ekipa_core/testing.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/src/data/rehearsal_gateway.dart';
import 'package:mobile/src/identity/name_only_verifier.dart';
import 'package:mobile/src/screens/home.dart';
import 'package:mobile/src/state/providers.dart';

/// A Thursday in term time, matching the goldens.
final DateTime _now = DateTime.utc(2026, 10, 20, 9);

/// The real app, wired the way `main()` wires it, against a scripted server.
///
/// The basemap resolves to `null` on purpose: this file is about routing, and
/// a test that needed a 77 KB asset to prove which screen is on would be
/// testing the asset.
Widget _app(Rehearsal stage) => ProviderScope(
  overrides: [
    gatewayProvider.overrideWithValue(
      RehearsalGateway(FakeClock(_now), stage),
    ),
    verifierProvider.overrideWithValue(const NameOnlyVerifier()),
    clockProvider.overrideWithValue(FakeClock(_now)),
    basemapProvider.overrideWith((ref) async => null),
  ],
  child: const EkipaApp(),
);

void main() {
  testWidgets('the shell builds on the design system', (tester) async {
    await tester.pumpWidget(_app(Rehearsal.waiting));
    await tester.pumpAndSettle();

    // Not a decorative assertion: it fails the moment someone builds a screen
    // out of a bare Scaffold and ad-hoc styling, which is how the v1 kit
    // stopped being a design system.
    expect(find.byType(EkipaScreen), findsOneWidget);
  });

  testWidgets('the shell shows what the server said, not what it guessed', (
    tester,
  ) async {
    // Same widget, same bindings, one different server answer. If the shell
    // ever decides a state for itself, these two stop diverging.
    await tester.pumpWidget(_app(Rehearsal.suspended));
    await tester.pumpAndSettle();
    expect(find.byType(SuspendedScreen), findsOneWidget);

    await tester.pumpWidget(_app(Rehearsal.waiting));
    await tester.pumpAndSettle();
    expect(find.byType(SuspendedScreen), findsNothing);
  });

  test('a port with no binding fails by name', () {
    // The failure this prevents is silent, not loud: a provider with a
    // convenient default would let a widget test pass while quietly depending
    // on a live project, and it would fail in CI on a Sunday for reasons
    // nobody could reproduce.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Matched on the message rather than the type: Riverpod wraps whatever a
    // provider throws, and the thing that has to survive is the sentence a
    // developer reads at 2am — which provider, and where to bind it.
    expect(
      () => container.read(gatewayProvider),
      throwsA(
        isA<Object>().having(
          (error) => error.toString(),
          'message',
          allOf(contains('gatewayProvider'), contains('composition root')),
        ),
      ),
    );
  });
}
