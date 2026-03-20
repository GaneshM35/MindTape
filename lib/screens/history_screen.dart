import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../services/database_service.dart';
import '../widgets/app_colors.dart';
import 'detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _database = DatabaseService.instance;
  late Future<List<JournalEntry>> _entriesFuture;
  /// First day of the month shown in the calendar.
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _calendarMonth = DateTime(n.year, n.month);
    _entriesFuture = _database.allEntriesLatestFirst();
  }

  void _reload() {
    setState(() {
      _entriesFuture = _database.allEntriesLatestFirst();
    });
  }

  String _formatDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String _preview(JournalEntry entry) {
    if (entry.mode == ReflectionMode.mindDump) {
      final t = entry.mindDumpText.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.isEmpty) return 'No text';
      if (t.length <= 80) return t;
      return '${t.substring(0, 80)}…';
    }
    final combined =
        entry.answers.where((s) => s.trim().isNotEmpty).join(' ');
    final normalized = combined.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return 'No text';
    if (normalized.length <= 80) return normalized;
    return '${normalized.substring(0, 80)}…';
  }

  Future<void> _openEntry(JournalEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(entry: entry),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<JournalEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load history: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final entries = snapshot.data ?? const <JournalEntry>[];
            final byKey = <String, JournalEntry>{
              for (final e in entries) e.dateKey: e,
            };

            return RefreshIndicator(
              onRefresh: () async {
                final f = _database.allEntriesLatestFirst();
                setState(() => _entriesFuture = f);
                await f;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _HistoryCalendar(
                        month: _calendarMonth,
                        entriesByDateKey: byKey,
                        onPrevMonth: () {
                          setState(() {
                            _calendarMonth =
                                DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                          });
                        },
                        onNextMonth: () {
                          setState(() {
                            _calendarMonth =
                                DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                          });
                        },
                        onTapDay: (entry) => _openEntry(entry),
                      ),
                    ),
                  ),
                  if (entries.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No entries yet. Log a day on Home to see ✔ on the calendar.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            elevation: 0,
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              title: Text(
                                _formatDate(entry.date),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                _preview(entry),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openEntry(entry),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Sunday-first grid: ✔ logged, ✖ missed (past day, no entry), today open without entry shows ·, future blank.
class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({
    required this.month,
    required this.entriesByDateKey,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<String, JournalEntry> entriesByDateKey;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final void Function(JournalEntry entry) onTapDay;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Column index 0 = Sunday … 6 = Saturday (matches S M T W T F S).
  static int _sundayFirstLeadingSlots(DateTime firstOfMonth) {
    final w = firstOfMonth.weekday; // Mon=1 … Sun=7
    return w % 7;
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final leading = _sundayFirstLeadingSlots(first);
    final today = _startOfDay(DateTime.now());
    final title = MaterialLocalizations.of(context).formatMonthYear(first);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevMonth,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textPrimary,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
                color: AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 1.05,
            ),
            itemCount: leading + lastDay,
            itemBuilder: (context, index) {
              if (index < leading) {
                return const SizedBox.shrink();
              }
              final day = index - leading + 1;
              final cellDate = DateTime(month.year, month.month, day);
              final key =
                  '${cellDate.year.toString().padLeft(4, '0')}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';
              final entry = entriesByDateKey[key];
              final startCell = _startOfDay(cellDate);

              final bool hasEntry = entry != null;
              final bool isFuture = startCell.isAfter(today);
              final bool isMissed = !hasEntry && startCell.isBefore(today);
              final bool isTodayOpen = !hasEntry && startCell == today;

              String symbol;
              Color symColor;
              if (hasEntry) {
                symbol = '✔';
                symColor = AppColors.accent;
              } else if (isMissed) {
                symbol = '✖';
                symColor = AppColors.textSecondary.withOpacity(0.85);
              } else if (isTodayOpen) {
                symbol = '·';
                symColor = AppColors.textSecondary.withOpacity(0.6);
              } else if (isFuture) {
                symbol = '';
                symColor = AppColors.textSecondary;
              } else {
                symbol = '';
                symColor = AppColors.textSecondary;
              }

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: entry != null ? () => onTapDay(entry) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        symbol,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1,
                          color: symColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '✔ logged  ·  ✖ missed  ·  · today (still open)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
