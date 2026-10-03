import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wagz_mobile/api.dart';
import 'fixtures.dart';

void main() {
  test(
    'loads UTF-8 public feed from configured backend without credentials',
    () async {
      final api = WagzApi(
        baseUrl: 'https://wagz.example/',
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://wagz.example/api/events');
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response.bytes(utf8.encode(jsonEncode(feedJson())), 200);
        }),
      );
      final feed = await api.events();
      expect(feed.events.first.description, 'Koncert u dvorištu kampusa.');
      api.close();
    },
  );

  test(
    'tip POST sends note and optional source, no personal profile',
    () async {
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/tips');
          expect(jsonDecode(request.body), {
            'note': 'Koncert u Osijeku',
            'url': 'https://example.org',
            'website': '',
          });
          return http.Response('{"ok":true}', 201);
        }),
      );
      await api.submitTip(
        note: ' Koncert u Osijeku ',
        url: ' https://example.org ',
      );
      api.close();
    },
  );

  test(
    'rate limiting surfaces backend message without automatic POST retry',
    () async {
      var calls = 0;
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient((request) async {
          calls++;
          return http.Response.bytes(
            utf8.encode('{"error":"Previše dojava."}'),
            429,
          );
        }),
      );
      await expectLater(
        api.submitTip(note: 'Dobra dojava'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Previše dojava.',
          ),
        ),
      );
      expect(calls, 1);
      api.close();
    },
  );

  test(
    'invalid server response and missing configuration are recoverable',
    () async {
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient((_) async => http.Response('<html>bad</html>', 200)),
      );
      await expectLater(api.events(), throwsA(isA<ApiException>()));
      api.close();
      final unconfigured = WagzApi(baseUrl: '');
      await expectLater(unconfigured.events(), throwsA(isA<ApiException>()));
      unconfigured.close();
    },
  );
}
