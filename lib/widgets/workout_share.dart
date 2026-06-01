import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../date_util.dart';
import '../fonts.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'share_image.dart';

/// 운동 기록 공유용 수집 데이터.
class _GymEntry {
  final String ex;
  final List<GymSet> sets;
  _GymEntry(this.ex, this.sets);

  /// 연속으로 같은 (무게, 횟수) 세트를 묶는다. 예: 30×20 두 번 → (30,20,2).
  List<({double w, double r, int count})> get groups {
    final out = <({double w, double r, int count})>[];
    for (final s in sets) {
      if (out.isNotEmpty && out.last.w == s.w && out.last.r == s.r) {
        final last = out.removeLast();
        out.add((w: last.w, r: last.r, count: last.count + 1));
      } else {
        out.add((w: s.w, r: s.r, count: 1));
      }
    }
    return out;
  }
}

class _WorkoutShareData {
  final String name;
  final DateTime date;
  final List<_GymEntry> gym;
  final List<MapEntry<String, String>> body; // label, "value unit"
  final List<String> cardio;
  _WorkoutShareData({
    required this.name,
    required this.date,
    required this.gym,
    required this.body,
    required this.cardio,
  });

  bool get isEmpty => gym.isEmpty && body.isEmpty && cardio.isEmpty;
}

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

_WorkoutShareData _collect(Store store) {
  final vd = store.viewDate();
  final k = DateUtil.dkey(vd);

  final gym = store.data.gymLogs
      .where((l) => l.date == k)
      .map((l) => _GymEntry(l.ex, l.sets))
      .toList();

  final body = <MapEntry<String, String>>[];
  for (final l in store.data.bodyLogs.where((l) => l.date == k)) {
    final m = store.bodyMeta(l.ex);
    body.add(MapEntry(m.label, '${_fmtNum(l.value)}${m.unit}'));
  }

  final cardio = store.cardioOf(k).map((c) => c.text).toList();

  return _WorkoutShareData(
    name: store.userName,
    date: vd,
    gym: gym,
    body: body,
    cardio: cardio,
  );
}

/// 헬스 한 종목을 텍스트 한 줄로: "벤치프레스 30 - 20 - 2" (다른 세트는 쉼표로 나열).
String _gymLine(_GymEntry e) {
  final parts = e.groups
      .map((g) => '${_fmtNum(g.w)} - ${_fmtNum(g.r)} - ${g.count}')
      .join(', ');
  return '${e.ex} $parts';
}

/// 복사용 텍스트. 형식: 날짜 / 이름 / (빈 줄) / 종목들.
String _buildWorkoutText(_WorkoutShareData d) {
  final b = StringBuffer();
  b.writeln('${d.date.month}/${d.date.day}');
  if (d.name.isNotEmpty) b.writeln(d.name);
  b.writeln();
  for (final e in d.gym) {
    b.writeln(_gymLine(e));
  }
  for (final e in d.body) {
    b.writeln('${e.key} ${e.value}');
  }
  for (final c in d.cardio) {
    b.writeln(c);
  }
  return b.toString().trimRight();
}

/// 보고 있는 날짜의 운동 기록을 복사용 텍스트로 만든다(테스트·재사용용).
String workoutShareText(Store store) => _buildWorkoutText(_collect(store));

/// 운동 기록 공유 모달.
void showWorkoutShare(BuildContext context) {
  final store = context.read<Store>();
  final data = _collect(store);
  showDialog(
    context: context,
    barrierColor: const Color(0xE0060707),
    builder: (_) => _WorkoutShareModal(data: data),
  );
}

class _WorkoutShareModal extends StatefulWidget {
  final _WorkoutShareData data;
  const _WorkoutShareModal({required this.data});

  @override
  State<_WorkoutShareModal> createState() => _WorkoutShareModalState();
}

class _WorkoutShareModalState extends State<_WorkoutShareModal> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final fname = '운동기록_${DateUtil.dkey(widget.data.date)}.png';
      await shareImageBytes(bytes, fname, '오늘의 운동 기록');
      if (mounted) showToast(context, '운동 기록 이미지를 공유했습니다');
    } catch (_) {
      if (mounted) showToast(context, '공유에 실패했습니다');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _buildWorkoutText(widget.data)));
    showToast(context, '운동 기록을 텍스트로 복사했습니다');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('운동 기록 공유',
                style: AppFonts.sans(
                    size: 14, color: AppColors.ink, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _WorkoutCardView(data: widget.data),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Btn(
                    label: '닫기',
                    filled: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Btn(
                    label: '텍스트 복사',
                    filled: false,
                    onTap: _copyText,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Btn(
                    label: _busy ? '처리 중…' : '이미지 공유',
                    filled: true,
                    onTap: _shareImage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : AppColors.panel,
          border: filled ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: AppFonts.sans(
                size: 12.5,
                color: filled ? AppColors.bg : AppColors.inkDim,
                weight: FontWeight.w700)),
      ),
    );
  }
}

/// 캡처용 운동 기록 카드 (기준 폭 1080, 내용에 맞춰 세로로 늘어남).
class _WorkoutCardView extends StatelessWidget {
  final _WorkoutShareData data;
  const _WorkoutCardView({required this.data});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${data.date.month}월 ${data.date.day}일 (${Config.dayNames[data.date.weekday % 7]})';
    return Container(
      width: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171A19), Color(0xFF0C0E0D)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(80, 90, 80, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('W O R K O U T',
                style: AppFonts.sans(
                    size: 30,
                    color: AppColors.accentSoft,
                    weight: FontWeight.w600)),
            const SizedBox(height: 18),
            Text(data.name.isEmpty ? '오늘의 운동' : data.name,
                style: AppFonts.display(size: 84, color: AppColors.ink)),
            const SizedBox(height: 10),
            Text(dateStr,
                style: AppFonts.serif(size: 40, color: AppColors.inkDim)),
            const SizedBox(height: 40),
            Container(height: 2, color: const Color(0x1AFFFFFF)),
            const SizedBox(height: 40),
            if (data.isEmpty)
              Text('기록된 운동이 없습니다',
                  style: AppFonts.serif(size: 40, color: AppColors.inkFaint))
            else ...[
              if (data.gym.isNotEmpty)
                _section('헬스', AppColors.gym, [
                  for (final e in data.gym) _gymRow(e),
                ]),
              if (data.body.isNotEmpty)
                _section('맨몸', AppColors.body, [
                  for (final e in data.body) _line('${e.key}  ${e.value}'),
                ]),
              if (data.cardio.isNotEmpty)
                _section('유산소', AppColors.accent, [
                  for (final c in data.cardio) _line(c),
                ]),
            ],
            const SizedBox(height: 24),
            Text('오늘부터 갓생  ·  Routine Tracker',
                style: AppFonts.sans(size: 28, color: const Color(0xFF4A5050))),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Color color, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 14,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 18),
            Text(title,
                style: AppFonts.sans(
                    size: 40, color: AppColors.ink, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 18),
          ...rows,
        ],
      ),
    );
  }

  Widget _gymRow(_GymEntry e) {
    final detail = e.groups
        .map((g) => '${_fmtNum(g.w)}kg × ${_fmtNum(g.r)}회 · ${g.count}세트')
        .join('  /  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(e.ex,
                style: AppFonts.sans(
                    size: 38, color: AppColors.ink, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Text(detail,
                textAlign: TextAlign.right,
                style: AppFonts.sans(size: 36, color: AppColors.inkDim)),
          ),
        ],
      ),
    );
  }

  Widget _line(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text,
          style: AppFonts.sans(
              size: 38, color: AppColors.ink, weight: FontWeight.w500)),
    );
  }
}
