import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';
import '../services/speech_to_text_service.dart';

/// Guided daily flow: one question at a time with voice dictation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const List<String> questions = [
    'How was your day?',
    'What did you do?',
    'What are you grateful for?',
    'What did you achieve?',
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _questionIndex = 0;
  final List<String> _answers = ['', '', '', ''];
  final SpeechToTextService _speechService = SpeechToTextService();

  bool _isListening = false;
  bool _speechReady = false;
  String _speechStatus = '';
  String _speechError = '';
  double _soundLevel = 0.0;
  String _pluginStatus = '';

  // "Resume" behavior: if the user starts listening again while there's already
  // recognized text for the current question, we append the new speech.
  String _listenBaseAnswer = '';
  bool _appendToAnswerOnResult = false;

  void _setStatusFromCurrentAnswer() {
    final recognizedTrimmed = _answers[_questionIndex].trim();

    if (recognizedTrimmed.isEmpty) {
      if (_speechError.isNotEmpty) {
        _speechStatus = 'error';
      } else if (_appendToAnswerOnResult) {
        _speechStatus = 'no_additional_speech';
      } else {
        _speechStatus = 'no_speech_detected';
      }
      return;
    }

    if (_appendToAnswerOnResult) {
      final baseTrimmed = _listenBaseAnswer.trim();
      if (recognizedTrimmed == baseTrimmed) {
        _speechStatus = 'no_additional_speech';
        return;
      }
    }

    _speechStatus = 'done';
  }

  String get _currentAnswer => _answers[_questionIndex];

  Future<void> _ensureSpeechReady() async {
    if (_speechReady) return;

    final granted = await _speechService.hasPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _speechError = 'Microphone permission not granted.';
        _speechStatus = 'error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_speechError),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await _speechService.initialize(
      onError: (message) {
        if (!mounted) return;
        setState(() => _speechError = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isNotEmpty ? message : 'Speech recognition error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _pluginStatus = status;
        });
      },
    );

    if (!mounted) return;
    setState(() => _speechReady = ok);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goBack() {
    if (_isListening) return;
    if (_questionIndex <= 0) return;
    setState(() => _questionIndex--);
  }

  void _goNext() {
    if (_isListening) return;
    if (_questionIndex >= HomeScreen.questions.length - 1) return;
    setState(() => _questionIndex++);
  }

  Future<void> _onMicPressed() async {
    await _ensureSpeechReady();
    if (!_speechReady) return;

    if (_isListening) {
      await _speechService.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _setStatusFromCurrentAnswer();
      });
      return;
    }

    // Start listening for the current question only.
    setState(() {
      _isListening = true;
      _speechStatus = '';
      _pluginStatus = '';
      _speechError = '';
      _soundLevel = 0.0;

      _listenBaseAnswer = _answers[_questionIndex];
      _appendToAnswerOnResult = _listenBaseAnswer.trim().isNotEmpty;

      if (!_appendToAnswerOnResult) {
        _answers[_questionIndex] = '';
      }
    });

    _speechService.listen(
      onResult: (result) {
        // Update the current answer live as recognition returns partial results.
        if (!mounted) return;
        final recognized = result.recognizedWords;
        // We decide status based on final answer content, so we don't rely
        // on timing of callbacks here.

        setState(() {
          if (_appendToAnswerOnResult) {
            final base = _listenBaseAnswer.trim();
            _answers[_questionIndex] =
                (base.isEmpty ? '' : '$base ') + recognized;
          } else {
            _answers[_questionIndex] = recognized;
          }
        });

        // Only finalize status when the plugin tells us this is a final result.
        // This avoids "No speech detected" flashing while the final transcript
        // is still arriving.
        if (result.finalResult) {
          setState(() {
            _setStatusFromCurrentAnswer();
            _isListening = false;
          });
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
    );
  }

  @override
  void dispose() {
    _speechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _questionIndex == HomeScreen.questions.length - 1;
    final question = HomeScreen.questions[_questionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindTape'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${_questionIndex + 1} of ${HomeScreen.questions.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        question,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _currentAnswer.isEmpty
                                  ? 'Tap the mic and speak — text will show here.'
                                  : _currentAnswer,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _currentAnswer.isEmpty
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: _MicButton(
                          onPressed: _onMicPressed,
                          isListening: _isListening,
                          soundLevel: _soundLevel,
                        ),
                      ),
                      if (_speechStatus.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _speechStatus == 'no_speech_detected'
                              ? (_speechError.isNotEmpty
                                  ? 'Speech error: $_speechError'
                                  : 'No speech detected. Check mic & language packs, then try again.')
                              : (_speechStatus == 'no_recognition'
                                  ? 'Mic heard audio, but speech recognition returned no text.'
                                  : (_speechStatus == 'no_additional_speech'
                                      ? 'No additional speech captured. Tap mic again to try again.'
                                  : (_speechStatus == 'done'
                                      ? 'Speech complete'
                                      : (_speechStatus == 'error'
                                          ? 'Speech error: $_speechError'
                                          : 'Speech: $_speechStatus')))),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_isListening) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Mic level: ${_soundLevel.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: _isListening
                              ? null
                              : () {
                                  setState(() {
                                    _answers[_questionIndex] = '';
                                    _speechStatus = '';
                                    _speechError = '';
                                    _soundLevel = 0.0;
                                  });
                                },
                          child: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_questionIndex > 0 && !_isListening) ? _goBack : null,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (!isLast && !_isListening) ? _goNext : null,
                      child: Text(isLast ? 'Save' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.onPressed,
    required this.isListening,
    required this.soundLevel,
  });

  final VoidCallback onPressed;
  final bool isListening;
  final double soundLevel;

  @override
  Widget build(BuildContext context) {
    final level = soundLevel.clamp(0.0, 1.0);
    final bgColor = isListening
        ? AppColors.accent.withOpacity(1.0)
        : AppColors.accent.withOpacity(0.55);
    final double glow = isListening ? 8.0 + (level * 28.0) : 6.0;

    return Material(
      color: bgColor,
      shape: CircleBorder(
        side: BorderSide(
          color: isListening
              ? Colors.white.withOpacity(0.28)
              : Colors.white.withOpacity(0.10),
          width: isListening ? 1.6 : 1.2,
        ),
      ),
      elevation: glow,
      shadowColor: AppColors.accent.withOpacity(isListening ? 0.75 : 0.35),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isListening ? 1.08 : 1.0,
        child: InkWell(
          customBorder: CircleBorder(
            side: BorderSide(
              color: isListening
                  ? Colors.white.withOpacity(0.28)
                  : Colors.white.withOpacity(0.10),
              width: isListening ? 1.6 : 1.2,
            ),
          ),
          onTap: onPressed,
          child: SizedBox(
            width: 96,
            height: 96,
            child: Icon(
              Icons.mic,
              size: 44,
              color: isListening ? Colors.white : Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }
}
