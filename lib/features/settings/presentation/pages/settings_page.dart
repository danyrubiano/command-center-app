import 'package:flutter/material.dart';

import 'package:command_center_app/core/services/settings_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentStoragePath = 'Loading...';
  bool _autoRouteClickCues = true;
  String _audioDeviceName = 'Loading...';
  String _clickKeywords = 'Loading...';
  String _cueKeywords = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    final dir = await SettingsService().getStorageDirectory();
    final autoRoute = await SettingsService().getAutoRouteClickCues();
    final deviceName = await SettingsService().getAudioOutputDeviceName();
    final clickK = await SettingsService().getClickTrackKeywords();
    final cueK = await SettingsService().getCueTrackKeywords();
    
    if (mounted) {
      setState(() {
        _currentStoragePath = dir.path;
        _autoRouteClickCues = autoRoute;
        _audioDeviceName = deviceName ?? 'System Default';
        _clickKeywords = clickK;
        _cueKeywords = cueK;
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

  Future<void> _pickAudioDevice() async {
    List<PlaybackDevice> devices = [];
    try {
      devices = SoLoud.instance.listPlaybackDevices();
    } catch (e) {
      print('Failed to list devices: $e');
    }

    if (devices.isEmpty) return;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Audio Output Device', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (ctx, idx) {
                    final device = devices[idx];
                    return ListTile(
                      title: Text(device.name),
                      trailing: device.isDefault ? const Icon(Icons.star, size: 16, color: Colors.amber) : null,
                      onTap: () async {
                        try {
                           SoLoud.instance.changeDevice(newDevice: device);
                           await SettingsService().setAudioOutputDevice(device.id, device.name);
                           setState(() {
                             _audioDeviceName = device.name;
                           });
                        } catch (e) {
                           print('Failed changing output device manually to ${device.name}: $e');
                        }
                        if (context.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }
  Future<void> _editKeywords(bool isClick) async {
    final title = isClick ? 'Click Track Keywords' : 'Cue Track Keywords';
    final initialValue = isClick ? _clickKeywords : _cueKeywords;
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Comma separated keywords',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Cancel')
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text), 
              child: const Text('Save')
            ),
          ]
        );
      }
    );

    if (result != null) {
      if (isClick) {
        await SettingsService().setClickTrackKeywords(result);
        if (mounted) setState(() => _clickKeywords = result);
      } else {
        await SettingsService().setCueTrackKeywords(result);
        if (mounted) setState(() => _cueKeywords = result);
      }
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
                 value: _autoRouteClickCues,
                 onChanged: (bool val) async {
                   setState(() {
                     _autoRouteClickCues = val;
                   });
                   await SettingsService().setAutoRouteClickCues(val);
                 },
               ),
               ListTile(
                 title: const Text('Audio Output Device'),
                 subtitle: Text(_audioDeviceName),
                 trailing: const Icon(Icons.settings_input_component, size: 20),
                 onTap: _pickAudioDevice,
               ),
            ]
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Track Identification',
            children: [
               ListTile(
                 title: const Text('Click Track Keywords'),
                 subtitle: Text(_clickKeywords, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                 trailing: const Icon(Icons.edit, size: 16),
                 onTap: () => _editKeywords(true),
               ),
               ListTile(
                 title: const Text('Cue Track Keywords'),
                 subtitle: Text(_cueKeywords, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                 trailing: const Icon(Icons.edit, size: 16),
                 onTap: () => _editKeywords(false),
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
