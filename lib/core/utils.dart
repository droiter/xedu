/// 通用日期 / 时间格式化工具。
library;

String ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String todayYmd() => ymd(DateTime.now());

/// 「45 分钟」「1 小时 5 分」
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes 分钟';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h 小时' : '$h 小时 $m 分';
}

/// 「约 3 分钟」用于单节课程。
String shortMinutes(int minutes) => '$minutes 分钟';
