import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const String _defaultUrl = 'https://knylrcbtvjqgziqbggmw.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtueWxyY2J0dmpxZ3ppcWJnZ213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NzU5OTUsImV4cCI6MjA4OTE1MTk5NX0.G6u5HPaqxT9yJTtRweiMfmrLTD9usbmjVZFEe1e3O7A';

  /// URL Supabase.
  /// 1. Injectée via --dart-define=SUPABASE_URL=...
  /// 2. Lue depuis le fichier .env si initialisé
  /// 3. Valeur par défaut si non disponible (ex: web release sans .env)
  static String get url {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (dotenv.isInitialized) {
      final val = dotenv.env['SUPABASE_URL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return _defaultUrl;
  }

  /// Clé anonyme Supabase.
  /// 1. Injectée via --dart-define=SUPABASE_ANON_KEY=...
  /// 2. Lue depuis le fichier .env si initialisé
  /// 3. Valeur par défaut si non disponible (ex: web release sans .env)
  static String get anonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (dotenv.isInitialized) {
      final val = dotenv.env['SUPABASE_ANON_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return _defaultAnonKey;
  }
}
