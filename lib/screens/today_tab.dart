import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../date_util.dart';
import '../fonts.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/workout_logger.dart';
import '../widgets/workout_share.dart';

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final vd = store.viewDate();
    final k = DateUtil.dkey(vd);
    final day = store.day(k);
    final tasks = store.buildTasks();

    // 하단 메모
    String noteText = store.isToday
        ? '${Config.notes[vd.weekday % 7]} 완벽보다 빈도 — 최소 기준만 넘기면 오늘은 성공입니다.'
        : '어제 기록을 확인·수정하고 있습니다. 빠뜨린 항목이 있다면 지금 채워두십시오.';
    final dday = DateUtil.ddayToExam();
    if (store.isToday && !store.usingProfile && dday > 0) {
      noteText += ' · SQLD 시험(8/22)까지 D-$dday';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        _DayNav(store: store, vd: vd),
        const SizedBox(height: 14),
        for (final t in tasks)
          _TaskCard(
            task: t,
            dateKey: k,
            done: day.checks[t.id] == true,
            onToggle: () => store.toggleCheck(t.id),
          ),
        const SizedBox(height: 4),
        _CardioCard(key: ValueKey('cardio-$k'), dateKey: k),
        if (store.hasWorkoutData(k)) ...[
          const SizedBox(height: 10),
          _WorkoutShareBar(store: store),
        ],
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: const BoxDecoration(
            color: AppColors.panel2,
            border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
          child: Text(noteText,
              style: AppFonts.serif(size: 12.5, color: AppColors.inkDim)),
        ),
      ],
    );
  }
}

class _DayNav extends StatelessWidget {
  final Store store;
  final DateTime vd;
  const _DayNav({required this.store, required this.vd});

  @override
  Widget build(BuildContext context) {
    final label = store.isToday
        ? '오늘'
        : '${vd.month}월 ${vd.day}일 (${Config.dayNames[vd.weekday % 7]}) · 어제';
    return Row(
      children: [
        _NavBtn(
          '‹ 어제',
          enabled: store.viewOffset > -1,
          onTap: () => store.shiftViewDay(-1),
        ),
        Expanded(
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: store.isToday ? AppColors.ink : AppColors.accentSoft,
              )),
        ),
        _NavBtn(
          '오늘 ›',
          enabled: store.viewOffset < 0,
          onTap: () => store.shiftViewDay(1),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _NavBtn(this.label, {required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: AppFonts.sans(
                  size: 12, color: AppColors.inkDim, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskItem task;
  final String dateKey;
  final bool done;
  final VoidCallback onToggle;
  const _TaskCard({
    required this.task,
    required this.dateKey,
    required this.done,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forType(task.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 좌측 색상 바 (카드 전체 높이로 늘어남).
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: Container(color: color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CheckBox(done: done),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.name,
                              style: AppFonts.sans(
                                size: 14.5,
                                weight: FontWeight.w600,
                                color: done ? AppColors.inkFaint : AppColors.ink,
                                height: 1.3,
                              ).copyWith(
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            if (task.desc != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(task.desc!,
                                    style: AppFonts.sans(
                                        size: 12,
                                        color: AppColors.inkDim,
                                        height: 1.45)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Pill(task.pill, color),
                    ],
                  ),
                ),
                if (task.workout != null)
                  WorkoutLogger(
                    key: ValueKey('$dateKey-${task.workout!.type}'),
                    dateKey: dateKey,
                    workout: task.workout!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 유산소 기록 (선택). 날마다 자유 형식으로 추가/삭제.
class _CardioCard extends StatefulWidget {
  final String dateKey;
  const _CardioCard({super.key, required this.dateKey});

  @override
  State<_CardioCard> createState() => _CardioCardState();
}

class _CardioCardState extends State<_CardioCard> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    context.read<Store>().addCardio(widget.dateKey, t);
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final logs = store.cardioOf(widget.dateKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('유산소',
                  style: AppFonts.sans(
                      size: 14, color: AppColors.ink, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('선택 · 자유 형식',
                  style: AppFonts.sans(size: 11, color: AppColors.inkFaint)),
            ],
          ),
          const SizedBox(height: 4),
          Text("예: 런닝 3km - 27'",
              style: AppFonts.sans(size: 11, color: AppColors.inkFaint)),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final l in logs) _cardioRow(l),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  style: AppFonts.sans(size: 13, color: AppColors.ink),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  decoration: inputDecoration('유산소 기록 추가'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('추가',
                      style: AppFonts.sans(
                          size: 13,
                          color: AppColors.accentSoft,
                          weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardioRow(CardioLog l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(l.text,
                style: AppFonts.sans(size: 13, color: AppColors.ink)),
          ),
          GestureDetector(
            onTap: () => context.read<Store>().removeCardio(l),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('×',
                  style: AppFonts.sans(size: 16, color: AppColors.inkFaint)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 운동 기록 공유 버튼 (이미지 + 텍스트).
class _WorkoutShareBar extends StatelessWidget {
  final Store store;
  const _WorkoutShareBar({required this.store});

  Future<void> _onTap(BuildContext context) async {
    if (store.userName.isEmpty) {
      final name = await _askName(context);
      if (name != null && name.trim().isNotEmpty) {
        store.setUserName(name.trim());
      }
    }
    if (context.mounted) showWorkoutShare(context);
  }

  Future<String?> _askName(BuildContext context) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('이름을 입력하세요',
            style: AppFonts.sans(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          style: AppFonts.sans(size: 14, color: AppColors.ink),
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          decoration: inputDecoration('예: 이재원'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('건너뛰기', style: AppFonts.sans(color: AppColors.inkDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: Text('확인',
                style: AppFonts.sans(
                    color: AppColors.accentSoft, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.gym),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('운동 기록 공유 (이미지 · 텍스트)',
            style: AppFonts.sans(
                size: 13, color: AppColors.gym, weight: FontWeight.w700)),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool done;
  const _CheckBox({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: done ? AppColors.done : Colors.transparent,
        border: Border.all(
            color: done ? AppColors.done : AppColors.line, width: 2),
        borderRadius: BorderRadius.circular(7),
      ),
      child: done
          ? const Icon(Icons.check, size: 14, color: AppColors.bg)
          : null,
    );
  }
}
