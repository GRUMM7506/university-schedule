import 'package:shared_preferences/shared_preferences.dart';

/// Persists the refresh token across app restarts.
///
/// The access token is intentionally NOT persisted here: it's short-lived
/// and kept in memory only (on [ApiClient]). On a fresh app start we use the
/// stored refresh token to silently obtain a new access token.
class TokenStore {
  static const _refreshTokenKey = 'refresh_token';

  SharedPreferences? _prefs;

  /// Returns the cached [SharedPreferences] instance, initialising it on
  /// first access. Subsequent calls are synchronous.
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_refreshTokenKey);
  }
}
