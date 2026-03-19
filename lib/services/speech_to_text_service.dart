import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Thin wrapper around the `speech_to_text` plugin.
///
/// Keeping this in `services/` helps the UI layer stay focused on state and
/// navigation rather than plugin lifecycle.
class SpeechToTextService {
  SpeechToTextService();

  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  String? _lastErrorMsg;

  Future<bool> initialize({
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) => onStatus?.call(status),
      onError: (errorNotification) {
        _lastErrorMsg = errorNotification.errorMsg;
        onError?.call(errorNotification.errorMsg);
      },
    );
    return _speechEnabled;
  }

  bool get isInitialized => _speechEnabled;

  String? get lastErrorMsg => _lastErrorMsg ?? _speech.lastError?.errorMsg;

  String get lastStatus => _speech.lastStatus;

  /// Checks if the user has granted microphone permission.
  /// Can be called before [initialize].
  Future<bool> hasPermission() => _speech.hasPermission;

  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    void Function(double level)? onSoundLevelChange,
  }) async {
    await _speech.listen(
      // Use non-deprecated options for better cross-version compatibility.
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

  Future<void> stop() async {
    await _speech.stop();
  }
}

