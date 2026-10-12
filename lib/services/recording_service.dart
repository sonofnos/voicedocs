import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Wraps the `record` package for microphone capture. Kept separate from the
/// widget layer so recording can be swapped or mocked without touching UI
/// code.
class RecordingService {
  final AudioRecorder _recorder;
  String? _currentPath;

  RecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voicedocs_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    _currentPath = path;
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    _currentPath = null;
    return path;
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  String? get currentPath => _currentPath;
}
