import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url {
    if (dotenv.isInitialized) {
      return dotenv.env['SUPABASE_URL'] ?? '';
    }
    return const String.fromEnvironment('SUPABASE_URL');
  }

  static String get anonKey {
    if (dotenv.isInitialized) {
      return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    }
    return const String.fromEnvironment('SUPABASE_ANON_KEY');
  }
}
