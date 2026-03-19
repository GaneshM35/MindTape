import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';

/// Guided daily flow: one question at a time (speech wiring comes later).
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

  String get _currentAnswer => _answers[_questionIndex];

  void _goBack() {
    if (_questionIndex <= 0) return;
    setState(() => _questionIndex--);
  }

  void _goNext() {
    if (_questionIndex >= HomeScreen.questions.length - 1) return;
    setState(() => _questionIndex++);
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
                          onPressed: () {
                            // Speech-to-text will be added in a later step.
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Listening will be enabled in the next step.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
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
                      onPressed: _questionIndex > 0 ? _goBack : null,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: isLast ? null : _goNext,
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
  const _MicButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppColors.accent.withOpacity(0.45),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 96,
          height: 96,
          child: Icon(Icons.mic, size: 44, color: Colors.white),
        ),
      ),
    );
  }
}
