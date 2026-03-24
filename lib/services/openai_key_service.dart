import 'package:shared_preferences/shared_preferences.dart';

/// Stores an optional OpenAI API key for Whisper. User-entered value takes
/// precedence over `--dart-define=OPENAI_API_KEY=...` (e.g. CI builds).
class OpenAiKeyService {
  OpenAiKeyService._();
  static final OpenAiKeyService instance = OpenAiKeyService._();

  static const String _prefsKey = 'openai_api_key';

  static const String compileTimeKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  /// Key saved in-app (empty if none). Does not include compile-time define.
  Future<String> getUserStoredKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefsKey)?.trim() ?? '';
  }

  /// User-stored key first, then `--dart-define=OPENAI_API_KEY` when building.
  Future<String> getEffectiveKey() async {
    final stored = await getUserStoredKey();
    if (stored.isNotEmpty) return stored;
    return compileTimeKey.trim();
  }

  Future<bool> hasWhisperKey() async =>
      (await getEffectiveKey()).isNotEmpty;

  Future<void> saveKey(String? raw) async {
    final p = await SharedPreferences.getInstance();
    final t = raw?.trim() ?? '';
    if (t.isEmpty) {
      await p.remove(_prefsKey);
    } else {
      await p.setString(_prefsKey, t);
    }
  }
}
