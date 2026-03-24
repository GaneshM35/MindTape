import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Thin wrapper around the `speech_to_text` plugin (on-device recognition).
class SpeechToTextService {
  SpeechToTextService();

  final SpeechToText _speech = SpeechToText();

  Future<bool> initialize({
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async {
    return _speech.initialize(
      onStatus: (status) => onStatus?.call(status),
      onError: (errorNotification) {
        onError?.call(errorNotification.errorMsg);
      },
    );
  }

  Future<bool> hasPermission() => _speech.hasPermission;

  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    void Function(double level)? onSoundLevelChange,
  }) async {
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      listenFor: listenFor,
      pauseFor: pauseFor,
      onResult: onResult,
      onSoundLevelChange: onSoundLevelChange,
    );
  }

  Future<void> stop() => _speech.stop();
}
