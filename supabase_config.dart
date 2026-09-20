import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase project credentials from compile-time environment
/// variables, e.g.:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
///
/// The app works fully offline without these — [isConfigured] gates every
/// place that would otherwise try to reach the network, and the Settings
/// screen tells the person cloud sync isn't set up rather than failing
/// silently.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> init() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
