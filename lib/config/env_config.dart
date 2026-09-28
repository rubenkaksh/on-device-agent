import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Returns the value of [key] from `.env`, or `null` when dotenv was never
/// loaded (e.g. tests that build services without running `main()`) or the
/// key is missing/empty. Prefer this over `dotenv.env` directly, which throws
/// [NotInitializedError] before [DotEnv.load] has been called.
String? envValue(String key) {
  if (!dotenv.isInitialized) return null;
  final value = dotenv.env[key];
  return (value == null || value.isEmpty) ? null : value;
}
