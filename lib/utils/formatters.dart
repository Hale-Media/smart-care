import 'package:intl/intl.dart';

class Fmt {
  Fmt._();
  static final _date = DateFormat('d MMM yyyy');
  static final _time = DateFormat('HH:mm');
  static final _dateTime = DateFormat('d MMM, HH:mm');

  static String date(DateTime d) => _date.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);

  /// "5m ago", "2h ago", "3d ago".
  static String ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
