import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../services/database_service.dart';
import 'detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _database = DatabaseService.instance;
  late Future<List<JournalEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _database.allEntriesLatestFirst();
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
            if (entries.isEmpty) {
              return const Center(
                child: Text('No entries yet. Tap the mic on Home to start.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetailScreen(entry: entry),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

