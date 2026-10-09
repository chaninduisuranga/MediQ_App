String formatWaitDuration(int totalMinutes) {
  final minutes = totalMinutes < 0 ? 0 : totalMinutes;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
