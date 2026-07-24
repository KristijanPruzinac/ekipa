/// Human, calm date/time formatting for invitations.
library;

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatWhen(DateTime d) {
  final day = _days[d.weekday - 1];
  final month = _months[d.month - 1];
  return '$day, ${d.day} $month · ${formatTime(d)}';
}

String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes / 60;
  return h == h.roundToDouble() ? '${h.toInt()}h' : '${minutes ~/ 60}h ${minutes % 60}m';
}

String endTimeLabel(DateTime start, int durationMin) {
  return formatTime(start.add(Duration(minutes: durationMin)));
}
