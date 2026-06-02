import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../date_util.dart';
import '../fonts.dart';
import '../store.dart';
import 'common.dart';
import 'share_image.dart';

/// 보고 있는 날짜의 핵심 기록을 축약 수집 (웹 Share.collect).
class _ShareData {
  final String dateStr;
  final String dowStr;
  final int doneCount;
  final int total;
  final int pct;
  final List<String> doneLabels;
  final List<MapEntry<String, String>> highlights; // label, value
  final List<String> finishedBooks;
  final int streak;
  _ShareData({
    required this.dateStr,
    required this.dowStr,
    required this.doneCount,
    required this.total,
    required this.pct,
    required this.doneLabels,
    required this.highlights,
    required this.finishedBooks,
    required this.streak,
  });
}

_ShareData _collect(Store store) {
  final vd = store.viewDate();
  final k = DateUtil.dkey(vd);
  final day = store.data.days[k];
  final tasks = store.buildTasks();
  // 취미 등 optional 항목은 진행률/연속 계산에서 제외(강제성 없음).
  final required = tasks.where((t) => !t.optional).toList();
  final doneCount = required.where((t) => day?.checks[t.id] == true).length;
  final pct = required.isEmpty ? 0 : (doneCount / required.length * 100).round();

  // 완료 태그는 체크된 항목 전체(취미 포함)를 보여준다.
  final doneLabels = tasks.where((t) => day?.checks[t.id] == true).map((t) {
    if (t.id == 'workout') return t.workout!.type == 'gym' ? '헬스' : '맨몸운동';
    return t.pill;
  }).toList();

  final highlights = <MapEntry<String, String>>[];
  final gymVol = store.gymVolumeOf(k);
  if (gymVol > 0) highlights.add(MapEntry('헬스 볼륨', '${comma(gymVol)} kg'));
  for (final l in store.data.bodyLogs.where((l) => l.date == k)) {
    final m = Config.bodyLog[l.ex];
    if (m != null) highlights.add(MapEntry(m.label, '${comma(l.value)} ${m.unit}'));
  }
  final readPages = store.data.readLogs
      .where((l) => l.date == k)
      .fold<int>(0, (s, l) => s + l.pages);
  if (readPages > 0) highlights.add(MapEntry('독서', '$readPages p'));

  final finishedBooks = store.data.books
      .where((b) => b.done && b.finDate == k)
      .map((b) => b.title)
      .toList();

  String pad(int n) => n.toString().padLeft(2, '0');
  return _ShareData(
    dateStr: '${vd.year}. ${pad(vd.month)}. ${pad(vd.day)}',
    dowStr: '${Config.dayNames[vd.weekday % 7]}요일',
    doneCount: doneCount,
    total: required.length,
    pct: pct,
    doneLabels: doneLabels,
    highlights: highlights.take(4).toList(),
    finishedBooks: finishedBooks,
    streak: store.streak(),
  );
}

/// 공유 카드 모달을 띄운다.
void showShareCard(BuildContext context) {
  final store = context.read<Store>();
  final data = _collect(store);
  showDialog(
    context: context,
    barrierColor: const Color(0xE0060707),
    builder: (_) => _ShareModal(data: data),
  );
}

class _ShareModal extends StatefulWidget {
  final _ShareData data;
  const _ShareModal({required this.data});

  @override
  State<_ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<_ShareModal> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    final fname = '갓생_${DateUtil.dkey(context.read<Store>().viewDate())}.png';
    setState(() => _busy = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await shareImageBytes(bytes, fname, '오늘부터 갓생 · Routine Tracker');
      if (mounted) showToast(context, '이미지를 공유했습니다');
    } catch (e) {
      if (mounted) showToast(context, '공유에 실패했습니다');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            Text('오늘의 기록 카드',
                style: AppFonts.sans(
                    size: 14, color: AppColors.ink, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            // 미리보기 (실제 캡처는 동일 위젯)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _ShareCardView(data: widget.data),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ModalBtn(
                    label: '닫기',
                    filled: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModalBtn(
                    label: _busy ? '처리 중…' : '이미지 공유',
                    filled: true,
                    onTap: _share,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('저장·공유한 이미지를 인스타그램 스토리에 올리면 됩니다',
                textAlign: TextAlign.center,
                style: AppFonts.serif(size: 11.5, color: AppColors.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _ModalBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ModalBtn(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : AppColors.panel,
          border: filled ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: AppFonts.sans(
                size: 13,
                color: filled ? AppColors.bg : AppColors.inkDim,
                weight: FontWeight.w700)),
      ),
    );
  }
}

/// 9:16 스토리 카드. 기준 폭 1080 기반으로 그린 뒤 FittedBox로 스케일.
class _ShareCardView extends StatelessWidget {
  final _ShareData data;
  const _ShareCardView({required this.data});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: 1080,
        height: 1920,
        child: Stack(
          children: [
            // 배경 그라데이션
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF171A19), Color(0xFF0C0E0D)],
                ),
              ),
            ),
            // 상단 오렌지 글로우
            Positioned(
              right: -160,
              top: -160,
              child: Container(
                width: 900,
                height: 900,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x4DD8662F), Color(0x00D8662F)],
                  ),
                ),
              ),
            ),
            // 외곽 테두리
            Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x12FFFFFF), width: 2),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            // 내용 — Stack의 비배치 자식은 loose 제약을 받아 좁게 좌측 정렬되므로,
            // SizedBox(width: infinity)로 카드 전체 폭을 차지하게 해 중앙 정렬을 보장한다.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(70, 130, 70, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Text('T O D A Y   I   S T A R T',
                      style: AppFonts.sans(
                          size: 30,
                          color: AppColors.accentSoft,
                          weight: FontWeight.w600)),
                  const SizedBox(height: 26),
                  Text('오늘부터 갓생',
                      style: AppFonts.display(size: 92, color: AppColors.ink)),
                  const SizedBox(height: 18),
                  Text('${data.dateStr}  ·  ${data.dowStr}',
                      style: AppFonts.serif(size: 38, color: AppColors.inkDim)),
                  const SizedBox(height: 60),
                  _BigRing(pct: data.pct, doneCount: data.doneCount, total: data.total),
                  const SizedBox(height: 60),
                  _StreakPill(streak: data.streak),
                  const SizedBox(height: 70),
                  Text('— 오늘의 기록 —',
                      style: AppFonts.sans(size: 32, color: AppColors.inkFaint)),
                  const SizedBox(height: 30),
                  if (data.highlights.isNotEmpty)
                    _HighlightGrid(items: data.highlights)
                  else
                    Text('기록된 수치가 없습니다',
                        style: AppFonts.serif(size: 36, color: AppColors.inkFaint)),
                  if (data.doneLabels.isNotEmpty) ...[
                    const SizedBox(height: 50),
                    Text('— 완료한 루틴 —',
                        style: AppFonts.sans(size: 32, color: AppColors.inkFaint)),
                    const SizedBox(height: 30),
                    _DoneTags(labels: data.doneLabels),
                  ],
                  if (data.finishedBooks.isNotEmpty) ...[
                    const SizedBox(height: 50),
                    Text('— 오늘 완독 —',
                        style: AppFonts.sans(size: 32, color: AppColors.inkFaint)),
                    const SizedBox(height: 24),
                    for (final t in data.finishedBooks) _FinishedBanner(title: t),
                  ],
                  const Spacer(),
                  Text('오늘부터 갓생  ·  Routine Tracker',
                      style: AppFonts.sans(size: 30, color: const Color(0xFF4A5050))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigRing extends StatelessWidget {
  final int pct;
  final int doneCount;
  final int total;
  const _BigRing(
      {required this.pct, required this.doneCount, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 420,
      child: CustomPaint(
        painter: _BigRingPainter(pct),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$pct%',
                  style: AppFonts.display(size: 150, color: AppColors.ink)),
              Text('$doneCount / $total 완료',
                  style: AppFonts.sans(size: 36, color: AppColors.inkFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigRingPainter extends CustomPainter {
  final int pct;
  _BigRingPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const r = 190.0;
    final bg = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34;
    canvas.drawCircle(center, r, bg);
    if (pct > 0) {
      final fg = Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.accent, AppColors.accentSoft],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -3.14159 / 2,
        2 * 3.14159 * pct / 100,
        false,
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(_BigRingPainter old) => old.pct != pct;
}

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0x24D8662F),
        border: Border.all(color: const Color(0x66D8662F), width: 2),
        borderRadius: BorderRadius.circular(46),
      ),
      child: Text('🔥  연속 $streak일',
          style: AppFonts.sans(
              size: 44, color: AppColors.accentSoft, weight: FontWeight.w700)),
    );
  }
}

class _HighlightGrid extends StatelessWidget {
  final List<MapEntry<String, String>> items;
  const _HighlightGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _card(items[i]),
            if (i + 1 < items.length) ...[
              const SizedBox(width: 28),
              _card(items[i + 1]),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _card(MapEntry<String, String> it) {
    return Container(
      width: 440,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border.all(color: AppColors.line, width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 94,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sans(size: 30, color: AppColors.inkDim)),
                const SizedBox(height: 6),
                Text(it.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.display(size: 48, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneTags extends StatelessWidget {
  final List<String> labels;
  const _DoneTags({required this.labels});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 18,
      children: labels
          .map((l) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x297FAE6A),
                  border: Border.all(color: const Color(0x667FAE6A), width: 2),
                  borderRadius: BorderRadius.circular(33),
                ),
                child: Text(l,
                    style: AppFonts.sans(
                        size: 34,
                        color: const Color(0xFF9ED6B5),
                        weight: FontWeight.w600)),
              ))
          .toList(),
    );
  }
}

class _FinishedBanner extends StatelessWidget {
  final String title;
  const _FinishedBanner({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0x266FB98F),
        border: Border.all(color: const Color(0x736FB98F), width: 2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text('📖  $title',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.sans(
              size: 38, color: const Color(0xFF9ED6B5), weight: FontWeight.w700)),
    );
  }
}
