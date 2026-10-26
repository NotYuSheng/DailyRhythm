/// A Daylio entry exactly as exported, kept so any parse can be redone.
class DaylioRawEntry {
  final DateTime date; // the day it was assigned to
  final String loggedTime; // HH:MM as logged in Daylio
  final int? mood;
  final String activities; // pipe-separated, as exported
  final String note;

  DaylioRawEntry({required this.date, required this.loggedTime, this.mood, this.activities = '', this.note = ''});

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'logged_time': loggedTime,
      'mood': mood,
      'activities': activities,
      'note': note,
    };
  }

  factory DaylioRawEntry.fromMap(Map<String, dynamic> map) {
    return DaylioRawEntry(
      date: DateTime.parse(map['date'] as String),
      loggedTime: map['logged_time'] as String,
      mood: map['mood'] as int?,
      activities: map['activities'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }
}
