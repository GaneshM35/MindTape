/// Calendar date key in local time, matching [JournalEntry.dateKey] / SQLite `date` column.
String calendarDateKey(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

int _countConsecutiveBackward(Set<String> entryDateKeys, DateTime startLocal) {
  var d = DateTime(startLocal.year, startLocal.month, startLocal.day);
  var count = 0;
  while (entryDateKeys.contains(calendarDateKey(d))) {
    count++;
    d = d.subtract(const Duration(days: 1));
  }
  return count;
}

/// Consecutive days with a journal entry, local calendar.
///
/// - If there is an entry **today**, the count includes today and walks backward.
/// - Else if there is an entry **yesterday**, the count runs backward from yesterday
///   (logging today later extends the streak).
/// - Otherwise **0** — a full day was missed (no entry yesterday and not yet today).
int currentStreakDayCount(Set<String> entryDateKeys, DateTime nowLocal) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final todayKey = calendarDateKey(today);
  final yesterdayKey = calendarDateKey(yesterday);

  if (entryDateKeys.contains(todayKey)) {
    return _countConsecutiveBackward(entryDateKeys, today);
  }
  if (entryDateKeys.contains(yesterdayKey)) {
    return _countConsecutiveBackward(entryDateKeys, yesterday);
  }
  return 0;
}
