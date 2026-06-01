import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../fonts.dart';

/// 원형 진행률 게이지 (웹의 SVG ring 대응).
class ProgressRing extends StatelessWidget {
  final int pct; // 0~100
  final double size;
  final double stroke;
  const ProgressRing({
    super.key,
    required this.pct,
    this.size = 44,
    this.stroke = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(pct: pct, stroke: stroke),
        child: Center(
          child: Text(
            '$pct%',
            style: AppFonts.sans(
              size: size * 0.27,
              color: AppColors.ink,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int pct;
  final double stroke;
  _RingPainter({required this.pct, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final bg = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);

    if (pct > 0) {
      final fg = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      final sweep = 2 * math.pi * pct / 100;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.stroke != stroke;
}

/// 섹션 제목 (점 + 제목 + 우측 메타).
class SectionTitle extends StatelessWidget {
  final String title;
  final String? meta;
  const SectionTitle(this.title, {super.key, this.meta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: AppFonts.sans(
                  size: 15, color: AppColors.ink, weight: FontWeight.w700)),
          if (meta != null) ...[
            const Spacer(),
            Text(meta!,
                style: AppFonts.sans(size: 12, color: AppColors.inkFaint)),
          ],
        ],
      ),
    );
  }
}

/// 색상 라벨 알약.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  const Pill(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppFonts.sans(
          size: 10,
          color: AppColors.bg,
          weight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// 빈 상태 안내문 (명조체).
class EmptyStat extends StatelessWidget {
  final String text;
  const EmptyStat(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppFonts.serif(size: 12, color: AppColors.inkFaint),
      ),
    );
  }
}

/// 토스트 (웹의 UI.toast).
void showToast(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: AppFonts.sans(size: 13, color: AppColors.bg, weight: FontWeight.w700),
      ),
      backgroundColor: AppColors.done,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1900),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: const EdgeInsets.fromLTRB(40, 0, 40, 90),
      elevation: 0,
    ),
  );
}

/// 입력 필드 공통 데코레이션.
InputDecoration inputDecoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppFonts.sans(size: 13, color: AppColors.inkFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor: AppColors.panel2,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );

/// 공통 확인 다이얼로그 (웹의 confirm).
Future<bool> confirmDialog(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Text(message, style: AppFonts.sans(size: 14, color: AppColors.ink)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('취소', style: AppFonts.sans(color: AppColors.inkDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('확인',
              style: AppFonts.sans(color: AppColors.accentSoft, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return res ?? false;
}
