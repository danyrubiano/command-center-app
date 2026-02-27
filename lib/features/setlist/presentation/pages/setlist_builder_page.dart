import 'package:flutter/material.dart';

import 'package:command_center_app/features/setlist/presentation/pages/sequence_editor_page.dart';
import 'package:command_center_app/core/models/sequence.dart';

class SetlistBuilderPage extends StatelessWidget {
  const SetlistBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // PANEL 1: Saved Setlists
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saved Setlists', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: () {}),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text('Setlist ${index + 1}')),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 16, color: Colors.white54),
                                onPressed: () {},
                                tooltip: 'Edit Name',
                              ),
                            ],
                          ),
                          subtitle: const Text('8 Sequences'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () {},
                          ),
                          onTap: () {}, // Load setlist
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          

          // PANEL 3: Setlist Editor Area (Current Setlist)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).primaryColor, width: 2),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Editing: Setlist 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_circle, color: Colors.white),
                              label: const Text('Add Sequence', style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                // Will open a sequence selection modal
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text('Save Setlist', style: TextStyle(color: Colors.white)),
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: ReorderableListView(
                      onReorder: (oldIndex, newIndex) {},
                      children: List.generate(
                        4,
                        (index) => Card(
                          key: ValueKey(index),
                          color: Colors.black26,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text('Sequence A${index} - Am'),
                            subtitle: const Text('Pause After: 5s'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.tune, color: Colors.greenAccent),
                                  tooltip: 'Edit Sequence Mix/Tags',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SequenceEditorPage(
                                          sequence: Sequence(
                                            id: 'mock_sequence',
                                            name: 'Sequence A$index - Am',
                                            folderPath: '',
                                            tracks: [],
                                          )
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.timer, color: Colors.white70),
                                  tooltip: 'Edit Pause Duration',
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                  tooltip: 'Remove from Setlist',
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
