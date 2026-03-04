import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command_center_app/core/services/settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Helper to mock path provider for the unit test
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/mock/docs/path';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  group('SettingsService', () {
    test('SettingsService is a singleton', () {
      final s1 = SettingsService();
      final s2 = SettingsService();
      expect(identical(s1, s2), isTrue);
    });

    test('getStorageDirectory returns application documents by default when empty', () async {
      final service = SettingsService();
      await service.init();
      
      final dir = await service.getStorageDirectory();
      expect(dir.path, '/mock/docs/path');
    });

    test('Returns correctly formatted Custom Keywords', () async {
      final service = SettingsService();
      await service.init();
      
      // Initially, it should return default values
      final clickKeywords = await service.getClickTrackKeywords();
      expect(clickKeywords, contains('clic')); // Verifying the recent change

      final cueKeywords = await service.getCueTrackKeywords();
      expect(cueKeywords, 'cues, guide, guider, guia, vocal, english'); // Checking string removal
    });

    test('Saves custom keywords', () async {
      final service = SettingsService();
      await service.init();
      
      await service.setClickTrackKeywords('click, tempo');
      final newClick = await service.getClickTrackKeywords();
      expect(newClick, 'click, tempo');
    });

    test('Handles Auto Route Cues setting', () async {
      final service = SettingsService();
      await service.init();
      
      // Default is true 
      expect(await service.getAutoRouteClickCues(), isTrue);

      await service.setAutoRouteClickCues(false);
      expect(await service.getAutoRouteClickCues(), isFalse);
    });
  });
}
