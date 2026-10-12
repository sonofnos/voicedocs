import 'package:firebase_performance/firebase_performance.dart';

/// Wraps Firebase Performance Monitoring. One custom trace brackets the
/// full transcribe-then-structure flow, which is the part of the app most
/// likely to have a slow path worth measuring in production (native speech
/// recognition latency plus, when a real API key is configured, a network
/// round trip to the structuring endpoint).
class PerformanceService {
  final FirebasePerformance _performance;
  Trace? _activeTrace;

  PerformanceService(this._performance);

  Future<void> startTranscribeAndStructureTrace() async {
    final trace = _performance.newTrace('transcribe_and_structure');
    await trace.start();
    _activeTrace = trace;
  }

  void incrementMetric(String name, [int by = 1]) {
    _activeTrace?.incrementMetric(name, by);
  }

  Future<void> stopTranscribeAndStructureTrace() async {
    await _activeTrace?.stop();
    _activeTrace = null;
  }
}
