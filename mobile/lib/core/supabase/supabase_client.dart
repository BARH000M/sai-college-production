import 'package:supabase_flutter/supabase_flutter.dart';

/// Single entry point for the Supabase client.
///
/// `Supabase.initialize` is called once in `main.dart`, so `Supabase.instance`
/// is already a singleton. This accessor exists so repositories depend on a
/// named collaborator instead of reaching for the global in every file, which
/// keeps future testing and refactoring cheap.
abstract final class SaiSupabase {
  /// The initialised client. Throws [StateError] if accessed before
  /// `Supabase.initialize`, which only happens when configuration is missing.
  static SupabaseClient get client => Supabase.instance.client;
}