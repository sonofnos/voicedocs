import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/note.dart';
import '../../providers/providers.dart';

enum _FlowStage { idle, recording, transcribing, structuring, done }

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  _FlowStage _stage = _FlowStage.idle;
  String _transcript = '';
  String? _error;

  Future<void> _startRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _error = 'Microphone permission denied.');
      return;
    }
    await recorder.start();
    setState(() {
      _stage = _FlowStage.recording;
      _error = null;
    });
  }

  Future<void> _stopAndProcess() async {
    final recorder = ref.read(recordingServiceProvider);
    await recorder.stop();
    setState(() => _stage = _FlowStage.transcribing);

    final perf = ref.read(performanceServiceProvider);
    await perf.startTranscribeAndStructureTrace();

    try {
      final transcriber = ref.read(transcriptionServiceProvider);
      final transcript = await transcriber.transcribeLive();
      setState(() {
        _transcript = transcript;
        _stage = _FlowStage.structuring;
      });

      final structurer = ref.read(noteStructuringClientProvider);
      final structured = await structurer.structure(transcript);

      final note = Note(
        id: const Uuid().v4(),
        rawTranscript: transcript,
        title: structured.title,
        summary: structured.summary,
        actionItems: structured.actionItems,
        createdAt: DateTime.now(),
      );

      await ref.read(notesControllerProvider.notifier).addNote(note);

      setState(() => _stage = _FlowStage.done);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _stage = _FlowStage.idle;
      });
    } finally {
      await perf.stopTranscribeAndStructureTrace();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New note')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stage: ${_stage.name}', key: const Key('stageLabel')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            if (_stage == _FlowStage.idle)
              FilledButton.icon(
                key: const Key('startRecordingButton'),
                onPressed: _startRecording,
                icon: const Icon(Icons.mic),
                label: const Text('Start recording'),
              ),
            if (_stage == _FlowStage.recording)
              FilledButton.icon(
                key: const Key('stopRecordingButton'),
                onPressed: _stopAndProcess,
                icon: const Icon(Icons.stop),
                label: const Text('Stop and process'),
              ),
            if (_stage == _FlowStage.transcribing ||
                _stage == _FlowStage.structuring)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: CircularProgressIndicator(),
              ),
            if (_stage == _FlowStage.done) ...[
              const SizedBox(height: 12),
              Text('Transcript: $_transcript'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
