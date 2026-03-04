import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:window_manager/window_manager.dart';

import 'core/theme/dark_theme.dart';
import 'core/layout/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      title: 'Command Center',
      center: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const CommandCenterApp());
}

class CommandCenterApp extends StatelessWidget {
  const CommandCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Command Center',
      debugShowCheckedModeBanner: false,
      theme: appDarkTheme,
      home: const MainLayout(),
    );
  }
}
