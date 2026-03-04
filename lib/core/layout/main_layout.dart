import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:command_center_app/features/library/presentation/pages/library_page.dart';
import 'package:command_center_app/features/player/presentation/pages/player_page.dart';
import 'package:command_center_app/features/setlist/presentation/pages/setlist_builder_page.dart';
import 'package:command_center_app/features/settings/presentation/pages/settings_page.dart';
import 'package:command_center_app/core/models/setlist.dart';
import 'package:command_center_app/core/services/setlist_service.dart';
import 'package:window_manager/window_manager.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WindowListener {
  int _selectedIndex = 0;
  Setlist? _activeSetlist;
  bool _isFullScreen = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _initFullScreen();
    }
    _loadLastPlayedSetlist();
  }

  void _initFullScreen() async {
    if (_isDesktop) {
      bool isFull = await windowManager.isFullScreen();
      if (mounted) setState(() => _isFullScreen = isFull);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  void _toggleFullScreen() async {
    if (_isDesktop) {
      bool isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
    }
  }

  Future<void> _loadLastPlayedSetlist() async {
    final lastId = await SetlistService.getLastPlayedSetlistId();
    if (lastId != null) {
      final lists = await SetlistService.getSavedSetlists();
      for (var list in lists) {
        if (list.id == lastId) {
          if (mounted) setState(() => _activeSetlist = list);
          break;
        }
      }
    }
  }

  List<Widget> get _pages => [
    PlayerPage(
      key: ValueKey(_activeSetlist?.id),
      setlist: _activeSetlist,
      onSetlistChanged: (sl) {
        SetlistService.saveLastPlayedSetlistId(sl.id);
        setState(() {
          _activeSetlist = sl;
        });
      },
    ),
    SetlistBuilderPage(
      onSetlistActivated: (sl) {
        SetlistService.saveLastPlayedSetlistId(sl.id);
        setState(() {
          _activeSetlist = sl;
          _selectedIndex = 0; // Jump to Player
        });
      },
    ),
    const LibraryPage(),
    const SettingsPage(),
  ];

  final List<String> _titles = const [
    'COMMAND CENTER - PLAYER',
    'LIVE SETBUILDER',
    'SEQUENCE LIBRARY',
    'GLOBAL SETTINGS',
  ];

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
    await _loadLastPlayedSetlist(); // Keep the active setlist up-to-date across views
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  icon: Icon(
                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  onPressed: _toggleFullScreen,
                ),
              ]
            : null,
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).canvasColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.graphic_eq, size: 48, color: Colors.greenAccent),
                  SizedBox(height: 8),
                  Text(
                    'COMMAND CENTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              selectedColor: Theme.of(context).primaryColor,
              title: const Text('Player'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              selectedColor: Theme.of(context).primaryColor,
              title: const Text('Setlists'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              selectedColor: Theme.of(context).primaryColor,
              title: const Text('Library'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              selectedColor: Theme.of(context).primaryColor,
              title: const Text('Settings'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
