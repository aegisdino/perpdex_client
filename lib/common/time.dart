import 'package:intl/intl.dart';

int getElapsedTime(
  dynamic old, {
  DateTime? base,
  String? type = 'ms',
}) {
  if (old is String) old = DateTime.parse(old);
  final duration =
      (base == null) ? DateTime.now().difference(old) : base.difference(old);
  return type == 'h'
      ? duration.inHours
      : (type == 'ms' ? duration.inMilliseconds : duration.inSeconds);
}

int getElapsedMillis(
  DateTime old, {
  DateTime? base,
}) {
  return getElapsedTime(old, base: base, type: 'ms');
}

int getElapsedSeconds(
  DateTime old, {
  DateTime? base,
}) {
  return getElapsedTime(old, base: base, type: 's');
}

String getElapsedTimeString(DateTime startTime) {
  int elapsed = DateTime.now().difference(startTime).inSeconds;
  int secs;
  String retval = '';
  if (elapsed >= 60) {
    int min = elapsed ~/ 60;
    secs = elapsed % 60;
    retval = '${min}m';
  } else {
    secs = elapsed;
  }

  retval += ' ${secs}s';
  return retval;
}

int compareDate(DateTime? a, DateTime? b) {
  if (a != null && b != null) {
    return (a.difference(b).inSeconds < 0) ? -1 : 1;
  } else if (a != null) {
    return -1;
  } else {
    return 1;
  }
}

DateTime? minDateTime(DateTime? a, DateTime? b) {
  if (a != null && b != null) {
    return (a.difference(b).inSeconds < 0) ? a : b;
  } else if (a != null) {
    return a;
  } else {
    return b;
  }
}

String formatDuration(int seconds) {
  int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;
  int remainingSeconds = seconds % 60;

  String hoursStr = hours.toString().padLeft(2, '0');
  String minutesStr = minutes.toString().padLeft(2, '0');
  String secondsStr = remainingSeconds.toString().padLeft(2, '0');

  return '$hoursStr:$minutesStr:$secondsStr';
}

String utcDateText(dynamic date) {
  final dateMillis =
      (date is DateTime) ? date.millisecondsSinceEpoch : date.toInt();
  return DateFormat('yyyy-MM-dd HH:mm:ss')
      .format(DateTime.fromMillisecondsSinceEpoch(isUtc: true, dateMillis));
}

extension DateTimeExt on DateTime {
  String toUtcString() {
    return utcDateText(this);
  }
}
