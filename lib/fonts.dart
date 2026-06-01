import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// 웹 버전이 쓰던 세 가지 글꼴을 한 곳에서 제공.
///  - Black Han Sans  : 제목/숫자 (display)
///  - Gowun Batang    : 명조 메모 (serif)
///  - IBM Plex Sans KR : 본문 (default)
class AppFonts {
  AppFonts._();

  static TextStyle display({double? size, Color? color, double? letterSpacing}) =>
      GoogleFonts.blackHanSans(
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle serif({double? size, Color? color, FontWeight? weight}) =>
      GoogleFonts.gowunBatang(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1.6,
      );

  static TextStyle sans({
    double? size,
    Color? color,
    FontWeight? weight,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.ibmPlexSansKr(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
      );
}

/// 1234 -> "1,234" (JS toLocaleString 대용)
String comma(num n) {
  final isInt = n == n.roundToDouble();
  final s = isInt ? n.toInt().toString() : n.toString();
  final parts = s.split('.');
  final intPart = parts[0];
  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final grouped = (neg ? '-' : '') + buf.toString();
  return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
}
