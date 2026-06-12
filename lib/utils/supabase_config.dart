import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// URL Supabase.
  /// Sur le web : injectée via --dart-define=SUPABASE_URL=...
  /// Sur mobile : lue depuis le fichier .env
  static String get url {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (dotenv.isInitialized) {
      final val = dotenv.env['SUPABASE_URL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '';
  }

  /// Clé anonyme Supabase.
  /// Sur le web : injectée via --dart-define=SUPABASE_ANON_KEY=...
  /// Sur mobile : lue depuis le fichier .env
  static String get anonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (dotenv.isInitialized) {
      final val = dotenv.env['SUPABASE_ANON_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '';
  }
}
