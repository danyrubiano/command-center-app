import 'package:flutter/material.dart';

import 'package:command_center_app/features/setlist/presentation/pages/sequence_editor_page.dart';
import 'package:command_center_app/core/models/sequence.dart';
import 'package:command_center_app/core/services/file_extraction_service.dart';
import 'package:command_center_app/core/services/setlist_service.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Sequence> _sequences = [];
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _loadSequences();
  }

  Future<void> _loadSequences() async {
    final loaded = await FileExtractionService.loadSavedSequences();
    if (mounted) {
      setState(() {
        _sequences = loaded;
      });
    }
  }

  Future<void> _extractSequence() async {
    setState(() => _isExtracting = true);
    try {
      final Sequence? newSequence =
          await FileExtractionService.pickAndExtractSequence();
      if (newSequence != null) {
        setState(() {
          _sequences.add(newSequence);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error extracting file: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  void _renameSequence(Sequence sequence, int index) {
    TextEditingController ctrl = TextEditingController(text: sequence.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Sequence (Library)'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'New Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isNotEmpty &&
                    ctrl.text.trim() != sequence.name) {
                  try {
                    String oldPath = sequence.folderPath;
                    final updated =
                        await FileExtractionService.renameSequenceFolder(
                          sequence,
                          ctrl.text.trim(),
                        );

                    // Push global changes to any Setlists using this backend!
                    await SetlistService.updateSequenceReferencesGlobal(
                      oldPath,
                      updated,
                    );

                    if (mounted) {
                      setState(() {
                        _sequences[index] = updated;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Upload Area
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white24,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 16),
                  _isExtracting
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          onPressed: _extractSequence,
                          child: const Text(
                            'Upload / Extract Sequences (.zip)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Library List
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _sequences.isEmpty
                    ? const Center(
                        child: Text(
                          'No sequences extracted yet. Upload a .zip file.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _sequences.length,
                        itemBuilder: (context, index) {
                          final Sequence seq = _sequences[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.music_note,
                              color: Colors.white70,
                            ),
                            title: Row(
                              children: [
                                Text('${seq.name} - ${seq.detectedKey}'),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => _renameSequence(seq, index),
                                  tooltip: 'Rename Sequence Folder',
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${seq.tracks.length} Tracks • Discovered from ZIP',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.tune,
                                    color: Colors.greenAccent,
                                  ),
                                  tooltip: 'Open Sequence Editor',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SequenceEditorPage(sequence: seq),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Sequence?'),
                                        content: Text(
                                          'Are you sure you want to permanently delete "${seq.name}" from your local hard drive? Audio files will be erased.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                            ),
                                            onPressed: () async {
                                              try {
                                                await FileExtractionService.deleteSequenceFolder(
                                                  seq,
                                                );
                                                if (mounted) {
                                                  setState(() {
                                                    _sequences.removeAt(index);
                                                  });
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Delete failed: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                              if (ctx.mounted)
                                                Navigator.pop(ctx);
                                            },
                                            child: const Text(
                                              'Delete Permanently',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
