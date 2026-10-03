import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/api.dart';
import 'package:wagz_mobile/main.dart';
import '../test/fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native chronological feed, source tags, details and tip over HTTP',
    (tester) async {
      timezone.initializeTimeZones();
      await initializeDateFormatting('hr');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, dynamic>? receivedTip;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST' && request.uri.path == '/api/tips') {
          receivedTip =
              jsonDecode(await utf8.decodeStream(request))
                  as Map<String, dynamic>;
          request.response.statusCode = 201;
          request.response.write('{"ok":true}');
        } else if (request.uri.path == '/api/events') {
          request.response.write(jsonEncode(feedJson()));
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });
      final api = WagzApi(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(() async {
        api.close();
        await server.close(force: true);
      });

      await tester.pumpWidget(WagzApp(api: api));
      await tester.pumpAndSettle();
      // Allow the real socket response to complete without relying on animation state.
      for (
        var attempt = 0;
        attempt < 30 &&
            find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Ne možemo do poslužitelja'), findsNothing);
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('wagz-mobile-home');

      expect(find.byKey(const ValueKey('audience-students')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('event-card-student-concert')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Studenti'), findsOneWidget);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('wagz-mobile-feed');
      await tester.tap(
        find.byKey(const ValueKey('event-card-student-concert')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detalji događaja'), findsOneWidget);
      expect(find.textContaining('20:00'), findsWidgets);
      await binding.takeScreenshot('wagz-mobile-detail');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dojavi događaj'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Testna dojava samo u izoliranom testu.',
      );
      await tester.scrollUntilVisible(
        find.text('Pošalji dojavu'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Pošalji dojavu'));
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 30 && find.text('Dobra dojava.\nHvala!').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Dobra dojava.\nHvala!'), findsOneWidget);
      expect(receivedTip?['note'], 'Testna dojava samo u izoliranom testu.');
      await binding.takeScreenshot('wagz-mobile-tip-sent');
      expect(tester.takeException(), isNull);
    },
  );
}
