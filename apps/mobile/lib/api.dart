import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WagzApi {
  WagzApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;

  Uri _endpoint(String path) {
    final base = safeLink(baseUrl);
    if (base == null || base.hasQuery || base.hasFragment) {
      throw const ApiException(
        'Adresa WagZ poslužitelja nije postavljena. '
        'Pokreni aplikaciju uz WAGZ_API_BASE_URL.',
      );
    }
    return Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = _endpoint(path);
      final response =
          await (body == null
                  ? _client.get(uri, headers: {'Accept': 'application/json'})
                  : _client.post(
                      uri,
                      headers: {
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 20));
      Map<String, dynamic> payload = {};
      try {
        payload =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          payload['error'] as String? ??
              'Zahtjev nije uspio (${response.statusCode}). Pokušaj ponovno.',
        );
      }
      return payload;
    } on TimeoutException {
      throw const ApiException(
        'Poslužitelj se ne javlja. Provjeri vezu i pokušaj ponovno.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Ne možemo do poslužitelja. Provjeri internetsku vezu.',
      );
    } on FormatException {
      throw const ApiException(
        'Odgovor poslužitelja nije valjan. Pokušaj ponovno.',
      );
    } on TypeError {
      throw const ApiException(
        'Odgovor poslužitelja nije valjan. Pokušaj ponovno.',
      );
    }
  }

  Future<PublicFeed> events() async {
    final payload = await _request('/api/events');
    try {
      return PublicFeed.fromJson(payload);
    } on TypeError {
      throw const ApiException(
        'Pregled događaja nije valjan. Pokušaj ponovno.',
      );
    }
  }

  Future<void> submitTip({required String note, String? url}) async {
    await _request(
      '/api/tips',
      body: {
        'note': note.trim(),
        if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
        'website': '',
      },
    );
  }

  void close() => _client.close();
}
