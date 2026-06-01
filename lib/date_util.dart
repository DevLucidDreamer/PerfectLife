import 'config.dart';

/// 웹 버전 DateUtil에 대응.
class DateUtil {
  DateUtil._();

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// 'YYYY-MM-DD'
  static String dkey([DateTime? d]) {
    d ??= DateTime.now();
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  /// 'YYYY-MM'
  static String mkey([DateTime? d]) {
    d ??= DateTime.now();
    return '${d.year}-${_pad(d.month)}';
  }

  /// SQLD 시험까지 남은 일수
  static int ddayToExam() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Config.sqldExam.difference(today).inDays;
  }
}
