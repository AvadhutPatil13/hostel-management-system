import 'package:shared_preferences/shared_preferences.dart';

/// Persists student app-preference toggles using SharedPreferences.
///
/// Every value read by [StudentSettingsPage] goes through here so the
/// screen reflects real saved state on load, and every change is written
/// immediately rather than only on "Save Preferences" (that button now
/// just gives explicit confirmation / can be used to sync to a backend).
class SettingsService {
  SettingsService._();

  static const _kNotifications = 'pref_notifications';
  static const _kNoticeNotifications = 'pref_notice_notifications';
  static const _kFeeNotifications = 'pref_fee_notifications';
  static const _kComplaintNotifications = 'pref_complaint_notifications';
  static const _kSoundEffects = 'pref_sound_effects';
  static const _kVibration = 'pref_vibration';
  static const _kLanguage = 'pref_language';

  static Future<StudentPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();

    return StudentPreferences(
      notifications: prefs.getBool(_kNotifications) ?? true,
      noticeNotifications: prefs.getBool(_kNoticeNotifications) ?? true,
      feeNotifications: prefs.getBool(_kFeeNotifications) ?? true,
      complaintNotifications:
          prefs.getBool(_kComplaintNotifications) ?? true,
      soundEffects: prefs.getBool(_kSoundEffects) ?? true,
      vibration: prefs.getBool(_kVibration) ?? true,
      language: prefs.getString(_kLanguage) ?? 'English',
    );
  }

  static Future<void> setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  static Future<void> setNoticeNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNoticeNotifications, value);
  }

  static Future<void> setFeeNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFeeNotifications, value);
  }

  static Future<void> setComplaintNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kComplaintNotifications, value);
  }

  static Future<void> setSoundEffects(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSoundEffects, value);
  }

  static Future<void> setVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibration, value);
  }

  static Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, value);
  }

  /// Clears cached/local app data (not the account itself). Useful for a
  /// "Clear Cache" support action.
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Only clear cache-style keys, keep auth/session data intact.
    for (final key in prefs.getKeys()) {
      if (key.startsWith('cache_')) {
        await prefs.remove(key);
      }
    }
  }
}

class StudentPreferences {
  const StudentPreferences({
    required this.notifications,
    required this.noticeNotifications,
    required this.feeNotifications,
    required this.complaintNotifications,
    required this.soundEffects,
    required this.vibration,
    required this.language,
  });

  final bool notifications;
  final bool noticeNotifications;
  final bool feeNotifications;
  final bool complaintNotifications;
  final bool soundEffects;
  final bool vibration;
  final String language;
}