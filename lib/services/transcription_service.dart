import 'package:speech_to_text/speech_to_text.dart';

/// Wraps `speech_to_text`, which drives the platform's native speech
/// recognizer (SFSpeechRecognizer on iOS, SpeechRecognizer on Android).
///
/// This is deliberately on-device/native rather than a cloud transcription
/// API: no API key to manage, no per-minute billing, and it keeps working
/// without a network connection for the recognition step itself. See the
/// README for the full reasoning.
class TranscriptionService {
  final SpeechToText _speech;
  bool _initialized = false;

  TranscriptionService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  /// Listens and returns the final transcript once recognition settles.
  Future<String> transcribeLive() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return '';
    }

    final completer = <String>[];
    bool done = false;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          completer.add(result.recognizedWords);
          done = true;
        }
      },
    );

    while (!done && _speech.isListening) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return completer.isNotEmpty ? completer.first : '';
  }

  Future<void> stop() => _speech.stop();

  bool get isAvailable => _initialized;
}
