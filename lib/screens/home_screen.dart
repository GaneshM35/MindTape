import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../models/reflection_questions.dart';
import '../widgets/app_colors.dart';
import '../services/database_service.dart';
import '../services/speech_to_text_service.dart';
import 'history_screen.dart';

/// Guided daily flow: choose reflection depth, then voice (and optional typing) capture.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _questionIndex = 0;
  final List<String> _answers =
      List<String>.generate(reflectionPrompts.length, (_) => '');
  ReflectionMode? _sessionMode;

  late final TextEditingController _structuredFieldController;
  late final TextEditingController _mindDumpFieldController;

  final SpeechToTextService _speechService = SpeechToTextService();
  final DatabaseService _database = DatabaseService.instance;

  bool _isListening = false;
  bool _speechReady = false;
  String _speechStatus = '';
  String _speechError = '';
  double _soundLevel = 0.0;
  bool _isSaving = false;
  String _pluginStatus = '';

  String _listenBaseAnswer = '';
  bool _appendToAnswerOnResult = false;

  bool _checkingToday = true;
  bool _alreadyLoggedToday = false;
  JournalEntry? _todaysEntry;
  bool _editingToday = false;
  int _streakDays = 0;

  String _todayKey() {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int get _structuredPromptCount {
    if (_sessionMode == null) return 0;
    switch (_sessionMode!) {
      case ReflectionMode.minimum:
        return minimumReflectionPrompts.length;
      case ReflectionMode.deep:
        return reflectionPrompts.length;
      case ReflectionMode.mindDump:
        return 0;
    }
  }

  List<ReflectionPrompt> get _activePrompts {
    if (_sessionMode == null) return const [];
    switch (_sessionMode!) {
      case ReflectionMode.minimum:
        return minimumReflectionPrompts;
      case ReflectionMode.deep:
        return reflectionPrompts;
      case ReflectionMode.mindDump:
        return const [];
    }
  }

  void _resetAnswers() {
    for (var i = 0; i < _answers.length; i++) {
      _answers[i] = '';
    }
  }

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

  void _setStatusFromMindDump() {
    final recognizedTrimmed = _mindDumpFieldController.text.trim();
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

  /// Initializes speech recognition; may show the system microphone prompt
  /// the first time it runs ([SpeechToText.initialize]).
  Future<bool> _initializeSpeechPlugin() async {
    if (_speechReady) return true;

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

    if (!mounted) return false;
    setState(() => _speechReady = ok);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return ok;
  }

  Future<void> _ensureSpeechReady() async {
    await _initializeSpeechPlugin();
  }

  /// [hasPermission] does not prompt; we explain in-app first, then [initialize] requests OS access.
  Future<void> _promptForMicAccessOnLaunch() async {
    if (!mounted) return;

    final alreadyGranted = await _speechService.hasPermission();
    if (!mounted) return;

    if (alreadyGranted) {
      await _initializeSpeechPlugin();
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Microphone access'),
          content: Text(
            'MindTape uses the microphone to turn your spoken reflections into text. '
            'You can decline and type instead — voice is optional.',
            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow microphone'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;
    await _initializeSpeechPlugin();
  }

  void _goBack() {
    if (_isListening) return;
    if (_questionIndex <= 0) return;
    setState(() => _questionIndex--);
    _syncStructuredFieldFromAnswers();
  }

  void _syncStructuredFieldFromAnswers() {
    final t = _answers[_questionIndex];
    _structuredFieldController.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _goNext() {
    if (_isListening) return;
    final n = _structuredPromptCount;
    if (n == 0) return;
    if (_questionIndex >= n - 1) return;
    setState(() => _questionIndex++);
    _syncStructuredFieldFromAnswers();
  }

  void _pickMode(ReflectionMode mode) {
    setState(() {
      _sessionMode = mode;
      _questionIndex = 0;
      _resetAnswers();
      _speechStatus = '';
      _speechError = '';
      _pluginStatus = '';
      _soundLevel = 0.0;
    });
    _mindDumpFieldController.clear();
    if (mode != ReflectionMode.mindDump) {
      _syncStructuredFieldFromAnswers();
    }
  }

  void _leaveFlowToModePicker() {
    if (_isListening || _isSaving) return;
    setState(() {
      _sessionMode = null;
      _questionIndex = 0;
      _resetAnswers();
      _speechStatus = '';
      _speechError = '';
      _pluginStatus = '';
      _soundLevel = 0.0;
    });
    _mindDumpFieldController.clear();
    _structuredFieldController.clear();
  }

  @override
  void initState() {
    super.initState();
    _structuredFieldController = TextEditingController();
    _mindDumpFieldController = TextEditingController();
    _checkTodayLogged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _promptForMicAccessOnLaunch();
    });
  }

  Future<void> _checkTodayLogged() async {
    setState(() => _checkingToday = true);
    final entry = await _database.entryForDateKey(_todayKey());
    final streak = await _database.currentStreak();
    if (!mounted) return;
    setState(() {
      _todaysEntry = entry;
      _alreadyLoggedToday = entry != null;
      _checkingToday = false;
      _streakDays = streak;
    });
  }

  Future<void> _openHistory() async {
    if (_isListening || _isSaving) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const HistoryScreen(),
      ),
    );
    if (mounted) await _checkTodayLogged();
  }

  void _beginEditingToday() {
    final e = _todaysEntry;
    if (e == null || _isListening || _isSaving) return;
    setState(() {
      _editingToday = true;
      _sessionMode = e.mode;
      _resetAnswers();
      if (e.mode != ReflectionMode.mindDump) {
        for (var i = 0; i < _answers.length; i++) {
          _answers[i] = i < e.answers.length ? e.answers[i] : '';
        }
      }
      _questionIndex = 0;
      _speechStatus = '';
      _speechError = '';
      _pluginStatus = '';
      _soundLevel = 0.0;
    });
    if (e.mode == ReflectionMode.mindDump) {
      _mindDumpFieldController.value = TextEditingValue(
        text: e.mindDumpText,
        selection: TextSelection.collapsed(offset: e.mindDumpText.length),
      );
    } else {
      _syncStructuredFieldFromAnswers();
    }
  }

  void _cancelEditingToday() {
    if (_isListening || _isSaving) return;
    setState(() {
      _editingToday = false;
      _sessionMode = null;
      _questionIndex = 0;
      _resetAnswers();
      _speechStatus = '';
      _speechError = '';
      _pluginStatus = '';
      _soundLevel = 0.0;
    });
    _mindDumpFieldController.clear();
    _structuredFieldController.clear();
  }

  Future<void> _onMicPressed() async {
    await _ensureSpeechReady();
    if (!_speechReady) return;

    if (_sessionMode == ReflectionMode.mindDump) {
      if (_isListening) {
        await _speechService.stop();
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _setStatusFromMindDump();
        });
        return;
      }

      setState(() {
        _isListening = true;
        _speechStatus = '';
        _pluginStatus = '';
        _speechError = '';
        _soundLevel = 0.0;

        _listenBaseAnswer = _mindDumpFieldController.text;
        _appendToAnswerOnResult = _listenBaseAnswer.trim().isNotEmpty;

        if (!_appendToAnswerOnResult) {
          _mindDumpFieldController.clear();
        }
      });

      _speechService.listen(
        onResult: (result) {
          if (!mounted) return;
          final recognized = result.recognizedWords;

          setState(() {
            final String next;
            if (_appendToAnswerOnResult) {
              final base = _listenBaseAnswer.trim();
              next = (base.isEmpty ? '' : '$base ') + recognized;
            } else {
              next = recognized;
            }
            _mindDumpFieldController.value = TextEditingValue(
              text: next,
              selection: TextSelection.collapsed(offset: next.length),
            );
          });

          if (result.finalResult) {
            setState(() {
              _setStatusFromMindDump();
              _isListening = false;
            });
          }
        },
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
      );
      return;
    }

    if (_isListening) {
      await _speechService.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _setStatusFromCurrentAnswer();
      });
      return;
    }

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
        _structuredFieldController.clear();
      }
    });

    _speechService.listen(
      onResult: (result) {
        if (!mounted) return;
        final recognized = result.recognizedWords;

        setState(() {
          if (_appendToAnswerOnResult) {
            final base = _listenBaseAnswer.trim();
            _answers[_questionIndex] =
                (base.isEmpty ? '' : '$base ') + recognized;
          } else {
            _answers[_questionIndex] = recognized;
          }
          final t = _answers[_questionIndex];
          _structuredFieldController.value = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          );
        });

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

  bool _hasContentToSave() {
    if (_sessionMode == null) return false;
    if (_sessionMode == ReflectionMode.mindDump) {
      return _mindDumpFieldController.text.trim().isNotEmpty;
    }
    final n = _structuredPromptCount;
    return _answers.take(n).any((a) => a.trim().isNotEmpty);
  }

  Future<void> _saveEntryAndGoToHistory() async {
    if (_isListening || _isSaving || _sessionMode == null) return;

    if (!_hasContentToSave()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _sessionMode == ReflectionMode.mindDump
                ? 'Add some text before saving.'
                : 'Please add at least one answer before saving.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month, now.day);

      late final JournalEntry entry;
      if (_sessionMode == ReflectionMode.mindDump) {
        entry = JournalEntry(
          mode: ReflectionMode.mindDump,
          date: date,
          answers: List<String>.filled(reflectionPrompts.length, ''),
          mindDumpText: _mindDumpFieldController.text.trim(),
        );
      } else {
        final n = _structuredPromptCount;
        final trimmed = _answers.map((a) => a.trim()).toList();
        for (var i = n; i < trimmed.length; i++) {
          trimmed[i] = '';
        }
        entry = JournalEntry(
          mode: _sessionMode!,
          date: date,
          answers: trimmed,
        );
      }

      await _database.upsertEntry(entry);

      if (!mounted) return;

      final wasExistingToday = _todaysEntry != null;
      if (wasExistingToday) {
        final updated = await _database.entryForDateKey(_todayKey());
        if (!mounted) return;
        final streak = await _database.currentStreak();
        if (!mounted) return;
        setState(() {
          _todaysEntry = updated;
          _alreadyLoggedToday = updated != null;
          _editingToday = false;
          _sessionMode = null;
          _resetAnswers();
          _questionIndex = 0;
          _streakDays = streak;
        });
        _mindDumpFieldController.clear();
        _structuredFieldController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Today's entry updated."),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HistoryScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _speechStatusText(BuildContext context) {
    return Text(
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
    );
  }

  @override
  void dispose() {
    _speechService.stop();
    _structuredFieldController.dispose();
    _mindDumpFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showCompletedDay =
        !_checkingToday && _alreadyLoggedToday && !_editingToday;
    final showModePicker =
        !_checkingToday && !showCompletedDay && !_editingToday && _sessionMode == null;
    final showMindDump = !showCompletedDay &&
        !_checkingToday &&
        _sessionMode == ReflectionMode.mindDump;
    final prompts = _activePrompts;
    final n = _structuredPromptCount;
    final isLast = n > 0 && _questionIndex == n - 1;
    final prompt = prompts.isNotEmpty ? prompts[_questionIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindTape'),
        centerTitle: true,
        leading: _editingToday
            ? IconButton(
                tooltip: 'Close editor',
                onPressed: (_isListening || _isSaving) ? null : _cancelEditingToday,
                icon: const Icon(Icons.close),
              )
            : (!showCompletedDay && !_checkingToday && _sessionMode != null)
                ? IconButton(
                    tooltip: 'Choose another mode',
                    onPressed: (_isListening || _isSaving) ? null : _leaveFlowToModePicker,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: (_isListening || _isSaving) ? null : _openHistory,
            icon: const Icon(Icons.history),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _checkingToday
              ? const Center(child: CircularProgressIndicator())
              : showCompletedDay
                  ? _CompletedDayBody(
                      streakDays: _streakDays,
                      onViewHistory: (_isListening || _isSaving) ? null : _openHistory,
                      onEditToday: (_isListening || _isSaving) ? null : _beginEditingToday,
                    )
                  : showModePicker
                      ? _ReflectionModePicker(
                          streakDays: _streakDays,
                          onPick: _pickMode,
                        )
                      : showMindDump
                          ? _buildMindDumpColumn(context)
                          : _buildStructuredColumn(context, prompt!, isLast, n),
        ),
      ),
    );
  }

  Widget _buildMindDumpColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mind dump',
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
            clipBehavior: Clip.hardEdge,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Free flow',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No prompts — speak or type whatever is on your mind.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 160),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: _mindDumpFieldController,
                      maxLines: null,
                      minLines: 6,
                      keyboardType: TextInputType.multiline,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      onChanged: (_) => setState(() {}),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _mindDumpFieldController.text.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            height: 1.45,
                          ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: 'Write here, or use the mic below…',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: _MicButton(
                      onPressed: _onMicPressed,
                      isListening: _isListening,
                      soundLevel: _soundLevel,
                    ),
                  ),
                  if (_speechStatus.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _speechStatusText(context),
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
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: (_isListening || _isSaving) ? null : _saveEntryAndGoToHistory,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_todaysEntry != null ? 'Update' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildStructuredColumn(
    BuildContext context,
    ReflectionPrompt prompt,
    bool isLast,
    int n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Question ${_questionIndex + 1} of $n',
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
            clipBehavior: Clip.hardEdge,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    prompt.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                  ),
                  if (prompt.cue != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      prompt.cue!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 120),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: _structuredFieldController,
                      maxLines: null,
                      minLines: 4,
                      keyboardType: TextInputType.multiline,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      onChanged: (v) =>
                          setState(() => _answers[_questionIndex] = v),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _structuredFieldController.text.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            height: 1.45,
                          ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: 'Tap the mic and speak — or type here.',
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
                    _speechStatusText(context),
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
                              _structuredFieldController.clear();
                            },
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
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
                onPressed: (_isListening || _isSaving)
                    ? null
                    : (isLast ? _saveEntryAndGoToHistory : _goNext),
                child: _isSaving && isLast
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLast ? (_todaysEntry != null ? 'Update' : 'Save') : 'Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReflectionModePicker extends StatelessWidget {
  const _ReflectionModePicker({
    required this.streakDays,
    required this.onPick,
  });

  final int streakDays;
  final void Function(ReflectionMode mode) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeStreakCallout(
          streakDays: streakDays,
          context: _StreakCalloutContext.modePicker,
        ),
        Text(
          'How would you like to reflect today?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a mode — you can use voice or type in the next steps.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModeCard(
                  title: 'Minimum reflection',
                  description:
                      'Three core questions: how you felt, whether today moved you forward, and (optional) what mattered most.',
                  icon: Icons.looks_3_outlined,
                  onTap: () => onPick(ReflectionMode.minimum),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  title: 'Deep reflection',
                  description:
                      'Full guided flow — all eight prompts for a thorough daily review.',
                  icon: Icons.auto_awesome,
                  onTap: () => onPick(ReflectionMode.deep),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  title: 'Mind dump',
                  description:
                      'Free flow only — no questions, just empty your head onto the page.',
                  icon: Icons.notes_rounded,
                  onTap: () => onPick(ReflectionMode.mindDump),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _StreakCalloutContext { modePicker, completed }

class _HomeStreakCallout extends StatelessWidget {
  const _HomeStreakCallout({
    required this.streakDays,
    required this.context,
  });

  final int streakDays;
  final _StreakCalloutContext context;

  @override
  Widget build(BuildContext context) {
    final hasStreak = streakDays > 0;
    final headline = hasStreak
        ? (streakDays == 1 ? '1-day streak' : '$streakDays-day streak')
        : 'No active streak';

    final body = () {
      if (!hasStreak) {
        return 'Reflect today to begin. Miss a full day and your streak resets.';
      }
      switch (this.context) {
        case _StreakCalloutContext.modePicker:
          return 'Log today to keep your streak going.';
        case _StreakCalloutContext.completed:
          return 'Come back tomorrow to grow your streak.';
      }
    }();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasStreak ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
            color: hasStreak ? AppColors.accent : AppColors.textSecondary,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedDayBody extends StatelessWidget {
  const _CompletedDayBody({
    required this.streakDays,
    required this.onViewHistory,
    required this.onEditToday,
  });

  final int streakDays;
  final VoidCallback? onViewHistory;
  final VoidCallback? onEditToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: AppColors.accent.withOpacity(0.95),
                  ),
                  const SizedBox(height: 20),
                  _HomeStreakCallout(
                    streakDays: streakDays,
                    context: _StreakCalloutContext.completed,
                  ),
                  Text(
                    'Entry completed for the day',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can review past days or update today\'s responses anytime.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onViewHistory,
          icon: const Icon(Icons.history),
          label: const Text('View history'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onEditToday,
          icon: const Icon(Icons.edit_outlined),
          label: const Text("Edit today's entry"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: Colors.white.withOpacity(0.22)),
          ),
        ),
      ],
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
