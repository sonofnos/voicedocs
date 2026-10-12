import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../providers/providers.dart';
import '../record/record_screen.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) => notes.isEmpty
            ? const Center(child: Text('No notes yet. Record one.'))
            : ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) => _NoteTile(note: notes[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('recordFab'),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecordScreen()),
          );
          ref.read(notesControllerProvider.notifier).refresh();
        },
        child: const Icon(Icons.mic),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final icon = switch (note.syncStatus) {
      SyncStatus.synced => Icons.cloud_done,
      SyncStatus.pending => Icons.cloud_upload,
      SyncStatus.failed => Icons.cloud_off,
    };
    return ListTile(
      title: Text(note.title),
      subtitle: Text(
        '${note.summary}\n${DateFormat.yMMMd().add_jm().format(note.createdAt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(icon),
      isThreeLine: true,
    );
  }
}
