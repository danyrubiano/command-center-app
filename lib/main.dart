import 'package:flutter/material.dart';

import 'core/theme/dark_theme.dart';
import 'core/layout/main_layout.dart';

void main() {
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
