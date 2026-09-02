import 'package:flutter/services.dart';

/// Reads `.env` file bundled as a Flutter asset and parses key=value pairs.
///
/// The `.env` file must be listed under `flutter: assets:` in pubspec.yaml.
/// Lines starting with `#` and blank lines are ignored.
class EnvLoader {
  static Map<String, String>? _cache;

  /// Load and parse the `.env` asset. Returns a cached map on subsequent calls.
  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('.env');
    final parsed = <String, String>{};

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eq = trimmed.indexOf('=');
      if (eq < 1) continue;

      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();

      // Strip surrounding quotes if present.
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      parsed[key] = value;
    }

    _cache = parsed;
    return parsed;
  }

  /// Convenience: get a single value. Returns null if the key is missing.
  static Future<String?> get(String key) async {
    final env = await load();
    return env[key];
  }
}
