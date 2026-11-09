import 'package:supabase_flutter/supabase_flutter.dart';

/// Credentials arrive from the build, never from source:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
///
/// The anon key is public by design; every table and RPC behind it is guarded by
/// RLS plus the `school_tenant()` / `school_role()` checks, so the client can
/// never widen its own reach.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> initSupabase() async {
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
        'SUPABASE_URL و SUPABASE_ANON_KEY مطلوبان عبر --dart-define');
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

/// One client for the whole app — the same singleton rule as the web app.
SupabaseClient get db => Supabase.instance.client;

bool get isSignedIn => db.auth.currentSession != null;
