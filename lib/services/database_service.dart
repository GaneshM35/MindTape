import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/journal_entry.dart';
import '../models/reflection_questions.dart';

/// Local SQLite persistence for [JournalEntry].
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'mindtape.db';
  static const _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static String get _createEntriesTableSql {
    final cols = StringBuffer('''
CREATE TABLE journal_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL UNIQUE,
''');
    for (var i = 1; i <= reflectionPrompts.length; i++) {
      cols.writeln("  answer$i TEXT NOT NULL,");
    }
    final sql = cols.toString().trimRight();
    final fixed = sql.endsWith(',') ? sql.substring(0, sql.length - 1) : sql;
    return "$fixed,\n  entry_mode TEXT NOT NULL DEFAULT 'deep',\n  mind_dump TEXT NOT NULL DEFAULT ''\n);";
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(_createEntriesTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (var i = 5; i <= reflectionPrompts.length; i++) {
            await db.execute(
              'ALTER TABLE journal_entries ADD COLUMN answer$i TEXT NOT NULL DEFAULT \'\'',
            );
          }
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE journal_entries ADD COLUMN entry_mode TEXT NOT NULL DEFAULT 'deep'",
          );
          await db.execute(
            "ALTER TABLE journal_entries ADD COLUMN mind_dump TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  /// Insert or replace the entry for [entry.dateKey] (one row per calendar day).
  Future<int> upsertEntry(JournalEntry entry) async {
    final db = await database;
    return db.insert(
      'journal_entries',
      entry.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<JournalEntry>> allEntriesLatestFirst() async {
    final db = await database;
    final rows = await db.query(
      'journal_entries',
      orderBy: 'date DESC',
    );
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<JournalEntry?> entryForDateKey(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      'journal_entries',
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JournalEntry.fromMap(rows.first);
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) {
      await db.close();
    }
  }
}
