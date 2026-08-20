import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A hand-rolled PostgREST client, and a deliberate non-dependency.
///
/// **Intention — the worker adds no packages.** SC-2 asks for a written
/// justification for every package: what it does, why the standard library will
/// not do, its maintenance status, its transitive count. The honest answer for
/// `supabase` here is that this worker calls **five** RPCs by name, posts JSON,
/// and reads JSON back. `dart:io` and `dart:convert` do that in the ninety
/// lines below. Pulling in the client library would add realtime, storage,
/// auth, GoTrue and a websocket stack to a process whose entire job is to POST
/// five URLs and exit — and every one of those is a transitive dependency
/// compiled into the one runtime that holds the service-role key.
///
/// *Rejected — a direct Postgres connection (`package:postgres`).* It would be
/// faster and it would need a database password in the worker instead of a
/// service-role key, which is worse, not better: the key is scoped to the RPC
/// surface and the password is not. Going through PostgREST also means the
/// worker's writes travel the **same audited RPCs** the migrations declare,
/// rather than around them.
///
/// **The key.** `SUPABASE_SERVICE_ROLE_KEY` is read from the environment and
/// never printed, never logged, never included in an error message, and never
/// written to a file. It exists in exactly one place — the scheduler's secret
/// store — and this class is the only thing in the repository that reads it.
/// `toString` is overridden below for that reason: a stray `print(client)` in a
/// future job would otherwise put it in a CI log, and this repository is
/// public.
final class Postgrest {
  /// Creates a client against [baseUrl] holding [serviceRoleKey].
  Postgrest({
    required this.baseUrl,
    required String serviceRoleKey,
    HttpClient? httpClient,
  }) : _key = serviceRoleKey,
       _http = httpClient ?? HttpClient();

  /// Reads the project URL and the key from the environment.
  ///
  /// Fails loudly and immediately when either is missing. A worker that starts
  /// without credentials and discovers it on the first call has already logged
  /// a stack trace from the middle of a match run; one that refuses to start
  /// has told the scheduler something it can act on.
  factory Postgrest.fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final url = env['SUPABASE_URL'];
    final key = env['SUPABASE_SERVICE_ROLE_KEY'];
    if (url == null || url.isEmpty) {
      throw const MissingCredential('SUPABASE_URL');
    }
    if (key == null || key.isEmpty) {
      throw const MissingCredential('SUPABASE_SERVICE_ROLE_KEY');
    }
    return Postgrest(baseUrl: url, serviceRoleKey: key);
  }

  /// The project's base URL, e.g. `https://abc.supabase.co`.
  final String baseUrl;

  final String _key;
  final HttpClient _http;

  /// Calls `rpc/[name]` with [arguments] and decodes the answer.
  ///
  /// Throws [PostgrestFailure] on anything but 2xx. **The body is included in
  /// the message and the headers are not** — a Postgres error is diagnostic and
  /// safe to see; the `Authorization` header is the key.
  Future<Object?> rpc(
    String name, [
    Map<String, Object?> arguments = const {},
  ]) async {
    final uri = Uri.parse('$baseUrl/rest/v1/rpc/$name');
    final request = await _http.postUrl(uri);
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set('apikey', _key)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_key')
      // Ask for the whole answer rather than a stream of rows: every function
      // this worker calls returns a single scalar or a single jsonb.
      ..set('Accept', 'application/json');
    request.write(jsonEncode(arguments));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PostgrestFailure(name, response.statusCode, body);
    }
    if (body.isEmpty) return null;
    return jsonDecode(body);
  }

  /// Closes the underlying connections. A worker that exits without this leaves
  /// the process alive on the scheduler until the keep-alive expires.
  void close() => _http.close(force: true);

  /// Never the key.
  @override
  String toString() => 'Postgrest($baseUrl)';
}

/// A credential the worker cannot start without.
///
/// An `Exception` rather than a `StateError`, so the entry point can catch it
/// without catching programmer errors along with it — a bare `on Error` in
/// `main` would swallow the next real bug in this package.
final class MissingCredential implements Exception {
  /// Names the variable that is not set. **The name, never the value**: this
  /// message goes to a CI log in a public repository.
  const MissingCredential(this.variable);

  /// Which environment variable is missing.
  final String variable;

  @override
  String toString() => '$variable is not set';
}

/// What the server said no to.
final class PostgrestFailure implements Exception {
  /// Records a failed call.
  const PostgrestFailure(this.function, this.status, this.body);

  /// Which RPC.
  final String function;

  /// The HTTP status.
  final int status;

  /// The response body, which carries the Postgres error and its code.
  final String body;

  /// Whether the server refused rather than broke.
  ///
  /// A 401 or 403 from these functions means the worker's key is not
  /// `service_role` — which is a deployment fault, not a data fault, and the
  /// only sensible response is to stop rather than retry the other cities.
  bool get isRefusal => status == 401 || status == 403;

  @override
  String toString() => 'PostgrestFailure($function, $status): $body';
}
