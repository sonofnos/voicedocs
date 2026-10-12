enum SyncStatus { pending, synced, failed }

/// A structured field note. Raw transcript plus the fields pulled out of it
/// by a [NoteStructuringClient].
class Note {
  final String id;
  final String rawTranscript;
  final String title;
  final String summary;
  final List<String> actionItems;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final int syncAttempts;

  const Note({
    required this.id,
    required this.rawTranscript,
    required this.title,
    required this.summary,
    required this.actionItems,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
    this.syncAttempts = 0,
  });

  Note copyWith({
    SyncStatus? syncStatus,
    int? syncAttempts,
  }) {
    return Note(
      id: id,
      rawTranscript: rawTranscript,
      title: title,
      summary: summary,
      actionItems: actionItems,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
    );
  }

  Map<String, Object?> toLocalRow() {
    return {
      'id': id,
      'raw_transcript': rawTranscript,
      'title': title,
      'summary': summary,
      'action_items': actionItems.join('\u0001'),
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'sync_attempts': syncAttempts,
    };
  }

  factory Note.fromLocalRow(Map<String, Object?> row) {
    final itemsRaw = row['action_items'] as String? ?? '';
    return Note(
      id: row['id'] as String,
      rawTranscript: row['raw_transcript'] as String,
      title: row['title'] as String,
      summary: row['summary'] as String,
      actionItems: itemsRaw.isEmpty ? const [] : itemsRaw.split('\u0001'),
      createdAt: DateTime.parse(row['created_at'] as String),
      syncStatus: SyncStatus.values.byName(row['sync_status'] as String),
      syncAttempts: row['sync_attempts'] as int? ?? 0,
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'rawTranscript': rawTranscript,
      'title': title,
      'summary': summary,
      'actionItems': actionItems,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
