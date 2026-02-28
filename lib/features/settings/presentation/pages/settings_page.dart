import 'package:flutter/material.dart';

import 'package:command_center_app/core/services/settings_service.dart';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentStoragePath = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    final dir = await SettingsService().getStorageDirectory();
    if (mounted) {
      setState(() {
        _currentStoragePath = dir.path;
      });
    }
  }

  Future<void> _pickStorageFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Custom Storage Folder',
    );

    if (selectedDirectory != null) {
      await SettingsService().setCustomStoragePath(selectedDirectory);
      await _loadCurrentPath();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SettingsSection(
            title: 'Storage & File Management',
            children: [
               ListTile(
                 title: const Text('Live Configurations Folder'),
                 subtitle: Text(_currentStoragePath, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                 trailing: const Icon(Icons.folder_open, size: 20, color: Colors.blueAccent),
                 onTap: _pickStorageFolder,
               ),
            ]
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Audio Routing',
            children: [
               SwitchListTile(
                 activeTrackColor: Theme.of(context).primaryColor,
                 title: const Text('Auto-Route In-Ear Monitors (Click/Cues)'),
                 subtitle: const Text('Automatically hard-pans Click and Cues to Right Channel, and musical tracks to Left Channel when loading a sequence.'),
                 value: true,
                 onChanged: (bool val) {},
               ),
               ListTile(
                 title: const Text('Audio Output Device'),
                 subtitle: const Text('MacBook Pro Speakers'),
                 trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                 onTap: () {},
               ),
            ]
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Track Identification',
            children: [
               ListTile(
                 title: const Text('Click Track Keywords'),
                 subtitle: const Text('click, clk, metronome'),
                 trailing: const Icon(Icons.edit, size: 16),
                 onTap: () {},
               ),
               ListTile(
                 title: const Text('Cue Track Keywords'),
                 subtitle: const Text('cues, guide, vocal, english'),
                 trailing: const Icon(Icons.edit, size: 16),
                 onTap: () {},
               ),
            ]
          ),
           const SizedBox(height: 16),
          _SettingsSection(
            title: 'Appearance & Security',
            children: [
               SwitchListTile(
                 activeTrackColor: Theme.of(context).primaryColor,
                 title: const Text('Prevent Screen Sleep Status'),
                 subtitle: const Text('Keeps screen active during fullscreen live mode.'),
                 value: true,
                 onChanged: (bool val) {},
               ),
            ]
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...children,
        ],
      ),
    );
  }
}
