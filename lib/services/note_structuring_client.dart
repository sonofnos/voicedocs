import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of turning a raw transcript into structured fields.
class StructuredNote {
  final String title;
  final String summary;
  final List<String> actionItems;

  const StructuredNote({
    required this.title,
    required this.summary,
    required this.actionItems,
  });
}

/// Turns a raw voice transcript into structured fields (title, summary,
/// action items). Pluggable so the app can use a real hosted model when a
/// key is configured and fall back to a deterministic fake otherwise - the
/// same pattern used in agent-platform and chatstack-api.
abstract class NoteStructuringClient {
  Future<StructuredNote> structure(String transcript);
}

/// Calls an OpenAI-compatible chat completions endpoint to structure a
/// transcript. Works against OpenAI itself or any compatible gateway, since
/// the request/response shape is the de facto standard.
class OpenAiCompatibleStructuringClient implements NoteStructuringClient {
  final String apiKey;
  final String baseUrl;
  final String model;
  final http.Client httpClient;

  OpenAiCompatibleStructuringClient({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  @override
  Future<StructuredNote> structure(String transcript) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'Extract a short title, a one paragraph summary, and a list '
                'of action items from the voice note transcript. Respond '
                'with strict JSON: {"title": string, "summary": string, '
                '"actionItems": string[]}. No prose outside the JSON.',
          },
          {'role': 'user', 'content': transcript},
        ],
        'temperature': 0.2,
      }),
    );

    if (response.statusCode != 200) {
      throw NoteStructuringException(
        'structuring endpoint returned ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        decoded['choices'][0]['message']['content'] as String;
    final fields = jsonDecode(content) as Map<String, dynamic>;

    return StructuredNote(
      title: fields['title'] as String? ?? 'Untitled note',
      summary: fields['summary'] as String? ?? '',
      actionItems: (fields['actionItems'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class NoteStructuringException implements Exception {
  final String message;
  NoteStructuringException(this.message);

  @override
  String toString() => 'NoteStructuringException: $message';
}

/// Deterministic fallback used whenever no API key is configured, and used
/// throughout tests so nothing in the app or its test suite requires a live
/// key. Produces a title from the first sentence, a summary that is the
/// trimmed transcript, and action items from lines starting with common verbs.
class FakeNoteStructuringClient implements NoteStructuringClient {
  @override
  Future<StructuredNote> structure(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return const StructuredNote(
        title: 'Empty note',
        summary: '',
        actionItems: [],
      );
    }

    final sentences = trimmed
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final title = _truncate(sentences.first.trim(), 60);

    final actionItems = <String>[];
    final actionVerbPattern = RegExp(
      r'^(call|email|follow up|send|schedule|check|review|fix|update|'
      r'contact|book|order|arrange)\b',
      caseSensitive: false,
    );
    for (final sentence in sentences) {
      final s = sentence.trim();
      if (actionVerbPattern.hasMatch(s)) {
        actionItems.add(s.endsWith('.') ? s.substring(0, s.length - 1) : s);
      }
    }

    return StructuredNote(
      title: title,
      summary: trimmed,
      actionItems: actionItems,
    );
  }

  String _truncate(String input, int maxLength) {
    if (input.length <= maxLength) return input;
    return '${input.substring(0, maxLength - 1)}…';
  }
}
