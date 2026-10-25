/// Date helpers shared by the data layer and screens.
///
/// Every entry's `date` column represents a calendar day, so it is always
/// stored as local midnight. Use [dayOf] before writing or querying by date.
DateTime dayOf(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// Combines the calendar day of [day] with the clock time of [time].
DateTime atTimeOfDay(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

/// Hours slept between [bedTime] and [wakeTime], using only their clock times.
///
/// The calendar dates of the two values are ignored, so a bedtime of 01:30 or
/// 23:30 followed by a 07:00 wake-up gives 5.5h or 7.5h respectively,
/// regardless of which day either time was recorded on.
double sleepDurationHours(DateTime bedTime, DateTime wakeTime) {
  final bedMinutes = bedTime.hour * 60 + bedTime.minute;
  final wakeMinutes = wakeTime.hour * 60 + wakeTime.minute;
  final minutes = (wakeMinutes - bedMinutes) % (24 * 60);
  return minutes / 60.0;
}
