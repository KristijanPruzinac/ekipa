import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase config injected at build/run time via --dart-define, e.g.:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Until a project is configured, the app runs against mock data (see
/// data/mock_data.dart), so the UI is fully explorable offline.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isBackendConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

Future<void> initSupabase() async {
  if (!isBackendConfigured) return;
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
