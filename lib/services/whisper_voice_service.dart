import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records microphone audio and transcribes with OpenAI Whisper (`whisper-1`).
///
/// Call [stopAndTranscribe] with a key from [OpenAiKeyService] (or build-time
/// fallback). On-device fallback is [SpeechToTextService] when no key is set.
class WhisperVoiceService {
  WhisperVoiceService._();
  static final WhisperVoiceService instance = WhisperVoiceService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  Future<bool> hasMicPermission({bool request = true}) =>
      _recorder.hasPermission(request: request);

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/mt_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _path!,
    );
  }

  /// Stops recording, uploads to Whisper, deletes the temp file. Returns transcript text.
  Future<String> stopAndTranscribe(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw StateError('Missing OpenAI API key');
    }

    final stoppedPath = await _recorder.stop();
    final p = stoppedPath ?? _path;
    _path = null;
    if (p == null) return '';
    final file = File(p);
    if (!await file.exists()) return '';

    try {
      return await _transcribeFile(p, key);
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
    if (_path != null) {
      final f = File(_path!);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
      _path = null;
    }
  }

  Future<void> stopIfRecording() async {
    if (await _recorder.isRecording()) {
      await cancelRecording();
    }
  }

  Future<Amplitude> getAmplitude() => _recorder.getAmplitude();

  Future<void> dispose() => _recorder.dispose();
}

Future<String> _transcribeFile(String filePath, String key) async {
  final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer $key';
  request.fields['model'] = 'whisper-1';
  request.files.add(await http.MultipartFile.fromPath('file', filePath));

  final streamed = await request.send();
  final body = await streamed.stream.bytesToString();

  if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
    final msg = _parseOpenAiError(body) ?? body;
    throw Exception(msg.isNotEmpty ? msg : 'Whisper HTTP ${streamed.statusCode}');
  }

  final map = jsonDecode(body) as Map<String, dynamic>;
  return (map['text'] as String? ?? '').trim();
}

String? _parseOpenAiError(String body) {
  try {
    final dynamic decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final e = decoded['error'] as Map;
      return e['message'] as String?;
    }
  } catch (_) {}
  return null;
}
