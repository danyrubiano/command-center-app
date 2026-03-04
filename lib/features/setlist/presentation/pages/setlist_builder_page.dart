import 'package:flutter/material.dart';

import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/models/setlist.dart';
import 'package:command_center_app/core/services/file_extraction_service.dart';
import 'package:command_center_app/core/services/setlist_service.dart';
import 'package:command_center_app/features/setlist/presentation/pages/sequence_editor_page.dart';

class SetlistBuilderPage extends StatefulWidget {
  final void Function(Setlist)? onSetlistActivated;

  const SetlistBuilderPage({super.key, this.onSetlistActivated});

  @override
  State<SetlistBuilderPage> createState() => _SetlistBuilderPageState();
}

class _SetlistBuilderPageState extends State<SetlistBuilderPage> {
  List<Setlist> _savedSetlists = [];
  List<Sequence> _availableSequences = [];

  Setlist? _currentSetlist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final setlists = await SetlistService.getSavedSetlists();
    final sequences = await FileExtractionService.loadSavedSequences();

    setState(() {
      _savedSetlists = setlists;
      _availableSequences = sequences;
      _isLoading = false;
    });
  }

  void _createNewSetlist() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _currentSetlist = Setlist(id: newId, name: 'New Setlist', sequences: []);
    });
  }

  void _deleteSetlist(Setlist setlist) async {
    await SetlistService.deleteSetlist(setlist.id);
    if (_currentSetlist?.id == setlist.id) {
      setState(() => _currentSetlist = null);
    }
    _loadData();
  }

  void _saveCurrentSetlist() async {
    if (_currentSetlist != null) {
      await SetlistService.saveSetlist(_currentSetlist!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Setlist Saved!')));
      }
      _loadData();
    }
  }

  void _addSequenceToSetlist(Sequence seq) {
    if (_currentSetlist == null) return;

    // Create a copy of the sequence to allow independent tag/mix adjustments per setlist without altering the global library permanently
    final Sequence copy = Sequence.fromJson(seq.toJson());
    // Give it a unique ID for the reorderable list
    final uniqueId = '${copy.id}_${DateTime.now().millisecondsSinceEpoch}';

    final newSeq = Sequence(
      id: uniqueId,
      name: copy.name,
      folderPath: copy.folderPath,
      tracks: copy.tracks,
      cueTags: copy.cueTags,
      detectedKey: copy.detectedKey,
      pauseAfterSeconds: copy.pauseAfterSeconds,
      pitchOverride: copy.pitchOverride,
    );

    setState(() {
      _currentSetlist!.sequences.add(newSeq);
    });
  }

  void _editSetlistName() {
    if (_currentSetlist == null) return;
    TextEditingController ctrl = TextEditingController(
      text: _currentSetlist!.name,
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Setlist Name'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    _currentSetlist!.name = ctrl.text.trim();
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editSequenceName(Sequence seq, int index) {
    TextEditingController ctrl = TextEditingController(text: seq.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Sequence Name'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    _currentSetlist!.sequences[index].name = ctrl.text.trim();
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Row(
        children: [
          // PANEL 1: Saved Setlists and Available Sequences
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
                  // Setlists Header
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saved Setlists',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.greenAccent,
                          ),
                          onPressed: _createNewSetlist,
                          tooltip: 'New Setlist',
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: _savedSetlists.length,
                      itemBuilder: (context, index) {
                        final sl = _savedSetlists[index];
                        final isSelected = _currentSetlist?.id == sl.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.2),
                          title: Text(
                            sl.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('${sl.sequences.length} Sequences'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.greenAccent,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (widget.onSetlistActivated != null) {
                                    widget.onSetlistActivated!(sl);
                                  }
                                },
                                tooltip: 'Load to Player',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _deleteSetlist(sl),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _currentSetlist = Setlist.fromJson(
                                sl.toJson(),
                              ); // Edit a clone
                            });
                          },
                        );
                      },
                    ),
                  ),

                  // Library / Sequences Header
                  Container(color: Colors.white12, height: 4),
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Library',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: _availableSequences.length,
                      itemBuilder: (context, index) {
                        final seq = _availableSequences[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.music_note,
                            color: Colors.blueAccent,
                          ),
                          title: Text(seq.name),
                          subtitle: Text(
                            seq.folderPath.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => _addSequenceToSetlist(seq),
                            tooltip: 'Add to current setlist',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PANEL 2: Setlist Editor Area (Current Setlist)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              child: _currentSetlist == null
                  ? const Center(
                      child: Text(
                        'Select or Create a Setlist to Edit',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Editing: ${_currentSetlist!.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white54,
                                    ),
                                    onPressed: _editSetlistName,
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_currentSetlist!.sequences.isNotEmpty)
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                      ),
                                      label: const Flexible(
                                        child: Text(
                                          'Load to Player',
                                          style: TextStyle(color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (widget.onSetlistActivated != null) {
                                          widget.onSetlistActivated!(
                                            _currentSetlist!,
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.save,
                                      color: Colors.white,
                                    ),
                                    label: const Flexible(
                                      child: Text(
                                        'Save Setlist',
                                        style: TextStyle(color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    onPressed: _saveCurrentSetlist,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white24, height: 1),
                        if (_currentSetlist!.sequences.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                'No Sequences Added.\nUse the Library panel to add songs.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                          ),
                        if (_currentSetlist!.sequences.isNotEmpty)
                          Expanded(
                            child: ReorderableListView(
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = _currentSetlist!.sequences
                                      .removeAt(oldIndex);
                                  _currentSetlist!.sequences.insert(
                                    newIndex,
                                    item,
                                  );
                                });
                              },
                              children: List.generate(
                                _currentSetlist!.sequences.length,
                                (index) {
                                  final seq = _currentSetlist!.sequences[index];
                                  return Card(
                                    key: ValueKey(seq.id),
                                    color: Colors.black26,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              seq.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: Colors.white54,
                                            ),
                                            onPressed: () =>
                                                _editSequenceName(seq, index),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        'Pause After: ${seq.pauseAfterSeconds}s | Key: ${seq.detectedKey}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.tune,
                                              color: Colors.greenAccent,
                                            ),
                                            tooltip: 'Edit Sequence Mix/Tags',
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      SequenceEditorPage(
                                                        sequence: seq,
                                                      ),
                                                ),
                                              ).then((_) {
                                                // Trigger rebuild in case sequence was mutated
                                                setState(() {});
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.timer,
                                              color: Colors.white70,
                                            ),
                                            tooltip: 'Edit Pause Duration',
                                            onPressed: () {
                                              _editPauseDuration(seq, index);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle,
                                              color: Colors.redAccent,
                                            ),
                                            tooltip: 'Remove from Setlist',
                                            onPressed: () {
                                              setState(() {
                                                _currentSetlist!.sequences
                                                    .removeAt(index);
                                              });
                                            },
                                          ),
                                          const Icon(
                                            Icons.drag_handle,
                                            color: Colors.white38,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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

  void _editPauseDuration(Sequence seq, int index) {
    TextEditingController ctrl = TextEditingController(
      text: seq.pauseAfterSeconds.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Auto-Pause Duration'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Seconds'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final int? val = int.tryParse(ctrl.text);
                if (val != null) {
                  setState(() {
                    _currentSetlist!.sequences[index].pauseAfterSeconds = val;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
