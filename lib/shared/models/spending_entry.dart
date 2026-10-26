/// Money spent on something that isn't a meal: a group event (a farewell
/// dinner, KTV, a wedding) or a gift. Kept apart from meals so food
/// spending means food.
class SpendingEntry {
  static const event = 'event';
  static const gift = 'gift';
  static const other = 'other';
  static const categories = [event, gift, other];
  static const labels = {event: 'Event', gift: 'Gift', other: 'Other'};

  final int? id;
  final DateTime date;
  final DateTime? time;
  final String label;
  final double amount;
  final String currency;
  final String category;
  final String? notes;
  final String? rawText; // original Daylio line, when imported

  SpendingEntry({
    this.id,
    required this.date,
    this.time,
    required this.label,
    required this.amount,
    this.currency = 'SGD',
    this.category = event,
    this.notes,
    this.rawText,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'time': time?.toIso8601String(),
        'label': label,
        'amount': amount,
        'currency': currency,
        'category': category,
        'notes': notes,
        'raw_text': rawText,
      };

  factory SpendingEntry.fromMap(Map<String, dynamic> map) => SpendingEntry(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        time: map['time'] == null ? null : DateTime.parse(map['time'] as String),
        label: map['label'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'SGD',
        category: map['category'] as String? ?? event,
        notes: map['notes'] as String?,
        rawText: map['raw_text'] as String?,
      );
}
