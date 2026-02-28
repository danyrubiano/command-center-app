import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  SharedPreferences? _prefs;

  static const String _customStoragePathKey = 'custom_storage_path';
  static const String _autoRouteClickCuesKey = 'auto_route_click_cues';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Gets the currently defined local storage directory for setlists and sequences.
  Future<Directory> getStorageDirectory() async {
    if (_prefs == null) await init();
    
    String? customPath = _prefs!.getString(_customStoragePathKey);
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
         return dir;
      }
    }
    
    // Default fallback
    return await getApplicationDocumentsDirectory();
  }

  /// Sets a new custom storage directory
  Future<void> setCustomStoragePath(String path) async {
    if (_prefs == null) await init();
    await _prefs!.setString(_customStoragePathKey, path);
  }

  /// Gets the raw string of the custom storage path if any
  Future<String?> getRawCustomStoragePath() async {
    if (_prefs == null) await init();
    return _prefs!.getString(_customStoragePathKey);
  }

  /// Gets the Auto-Route In-Ear Monitors preference
  Future<bool> getAutoRouteClickCues() async {
    if (_prefs == null) await init();
    return _prefs!.getBool(_autoRouteClickCuesKey) ?? true;
  }

  /// Sets the Auto-Route In-Ear Monitors preference
  Future<void> setAutoRouteClickCues(bool value) async {
    if (_prefs == null) await init();
    await _prefs!.setBool(_autoRouteClickCuesKey, value);
  }
}
