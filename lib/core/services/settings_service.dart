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
  static const String _audioOutputDeviceIdKey = 'audio_output_device_id';
  static const String _audioOutputDeviceNameKey = 'audio_output_device_name';
  static const String _clickTrackKeywordsKey = 'click_track_keywords';
  static const String _cueTrackKeywordsKey = 'cue_track_keywords';
  static const String _preventScreenSleepKey = 'prevent_screen_sleep';

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

  /// Gets the preferred Audio Output Device name, if any
  Future<String?> getAudioOutputDeviceName() async {
    if (_prefs == null) await init();
    return _prefs!.getString(_audioOutputDeviceNameKey);
  }

  /// Sets the preferred Audio Output Device
  Future<void> setAudioOutputDevice(int id, String name) async {
    if (_prefs == null) await init();
    await _prefs!.setInt(_audioOutputDeviceIdKey, id);
    await _prefs!.setString(_audioOutputDeviceNameKey, name);
  }

  /// Gets Click Track Keywords
  Future<String> getClickTrackKeywords() async {
    if (_prefs == null) await init();
    return _prefs!.getString(_clickTrackKeywordsKey) ?? 'click, clk, metronome';
  }

  /// Sets Click Track Keywords
  Future<void> setClickTrackKeywords(String keywords) async {
    if (_prefs == null) await init();
    await _prefs!.setString(_clickTrackKeywordsKey, keywords);
  }

  /// Gets Cue Track Keywords
  Future<String> getCueTrackKeywords() async {
    if (_prefs == null) await init();
    return _prefs!.getString(_cueTrackKeywordsKey) ??
        'cue, cues, guide, guider, guia, vocal, english';
  }

  /// Sets Cue Track Keywords
  Future<void> setCueTrackKeywords(String keywords) async {
    if (_prefs == null) await init();
    await _prefs!.setString(_cueTrackKeywordsKey, keywords);
  }

  /// Gets the Prevent Screen Sleep preference
  Future<bool> getPreventScreenSleep() async {
    if (_prefs == null) await init();
    return _prefs!.getBool(_preventScreenSleepKey) ?? true;
  }

  /// Sets the Prevent Screen Sleep preference
  Future<void> setPreventScreenSleep(bool value) async {
    if (_prefs == null) await init();
    await _prefs!.setBool(_preventScreenSleepKey, value);
  }
}
