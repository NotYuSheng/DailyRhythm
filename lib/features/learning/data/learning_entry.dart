/// How something was learnt.
class LearningHow {
  LearningHow._();

  /// Picked up while working.
  static const work = 'work';

  /// Set out to learn it: a course, a book, practice.
  static const deliberate = 'deliberate';

  /// From someone: a chat, a review, a mentor.
  static const conversation = 'conversation';

  static const all = [work, deliberate, conversation];

  static const labels = {work: 'On the job', deliberate: 'Deliberate', conversation: 'From someone'};
}

/// Something learnt, in a line, with an optional reflection: so what (why
/// it matters) and now what (what to do with it).
class LearningEntry {
  LearningEntry({
    this.id,
    required this.date,
    required this.time,
    required this.what,
    this.soWhat,
    this.nowWhat,
    this.topic,
    this.how = LearningHow.work,
    this.minutes,
    this.rpe,
  });

  final int? id;
  final DateTime date;
  final DateTime time;
  final String what;
  final String? soWhat;
  final String? nowWhat;

  /// What it was about ("Flutter", "Negotiation"), to see where learning goes.
  final String? topic;

  /// One of [LearningHow.all].
  final String how;

  /// Time spent, when it was more than a moment.
  final int? minutes;

  /// How hard it was, on the same 1–10 scale as exercise.
  final int? rpe;

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'time': time.toIso8601String(),
    'what': what,
    'so_what': soWhat,
    'now_what': nowWhat,
    'topic': topic,
    'how': how,
    'minutes': minutes,
    'rpe': rpe,
  };

  factory LearningEntry.fromMap(Map<String, dynamic> map) => LearningEntry(
    id: map['id'] as int?,
    date: DateTime.parse(map['date'] as String),
    time: DateTime.parse(map['time'] as String),
    what: map['what'] as String,
    soWhat: map['so_what'] as String?,
    nowWhat: map['now_what'] as String?,
    topic: map['topic'] as String?,
    how: LearningHow.all.contains(map['how']) ? map['how'] as String : LearningHow.work,
    minutes: map['minutes'] as int?,
    rpe: map['rpe'] as int?,
  );
}
