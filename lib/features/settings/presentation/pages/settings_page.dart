import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SettingsSection(
            title: 'Audio Routing',
            children: [
               SwitchListTile(
                 activeColor: Theme.of(context).primaryColor,
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
                 activeColor: Theme.of(context).primaryColor,
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
