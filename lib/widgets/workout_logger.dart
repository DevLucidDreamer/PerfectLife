import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../fonts.dart';
import '../models.dart';
import '../onboarding/routine_profile.dart';
import '../store.dart';
import 'common.dart';

/// 운동 기록 입력 영역. 헬스(세트별 무게×횟수) 또는 맨몸(종목별 수치).
class WorkoutLogger extends StatefulWidget {
  final String dateKey;
  final WorkoutDay workout;
  const WorkoutLogger({super.key, required this.dateKey, required this.workout});

  @override
  State<WorkoutLogger> createState() => _WorkoutLoggerState();
}

class _WorkoutLoggerState extends State<WorkoutLogger> {
  bool _saved = false;

  // 맨몸: ex -> controller
  final Map<String, TextEditingController> _bodyCtl = {};
  // 헬스: ex -> list of (w,r) controllers
  final Map<String, List<_SetCtl>> _gymCtl = {};
  // 헬스: 화면에 표시할 종목 순서 (운동 중 추가 가능)
  final List<String> _exNames = [];

  bool get _isGym => widget.workout.type == 'gym';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkoutLogger old) {
    super.didUpdateWidget(old);
    // 프로필 변경 등으로 종목이 추가되면 컨트롤러를 채워 넣는다(기존 입력은 유지).
    if (_isGym) {
      for (final ex in widget.workout.ex) {
        if (!_gymCtl.containsKey(ex)) {
          _addGymCtl(ex);
          _exNames.add(ex);
        }
      }
    }
  }

  /// 헬스 종목용 세트 컨트롤러를 만든다. 기존 기록이 있으면 채워 넣는다.
  void _addGymCtl(String ex) {
    final store = context.read<Store>();
    final existing = store.data.gymLogs
        .where((l) => l.date == widget.dateKey && l.ex == ex)
        .cast<GymLog?>()
        .firstWhere((l) => true, orElse: () => null);
    final sets = existing?.sets ?? [GymSet(0, 0)];
    _gymCtl[ex] = sets
        .map((s) => _SetCtl(
              w: TextEditingController(text: s.w > 0 ? _fmt(s.w) : ''),
              r: TextEditingController(text: s.r > 0 ? _fmt(s.r) : ''),
            ))
        .toList();
  }

  void _load() {
    final store = context.read<Store>();
    if (_isGym) {
      for (final ex in widget.workout.ex) {
        _exNames.add(ex);
        _addGymCtl(ex);
      }
    } else {
      final logs = store.data.bodyLogs.where((l) => l.date == widget.dateKey).toList();
      for (final ex in widget.workout.log) {
        final existing = logs.where((l) => l.ex == ex).cast<BodyLog?>().firstWhere(
              (l) => true,
              orElse: () => null,
            );
        _bodyCtl[ex] = TextEditingController(
            text: existing != null && existing.value > 0 ? _fmt(existing.value) : '');
      }
    }
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in _bodyCtl.values) {
      c.dispose();
    }
    for (final list in _gymCtl.values) {
      for (final s in list) {
        s.w.dispose();
        s.r.dispose();
      }
    }
    super.dispose();
  }

  void _saveBody() {
    final values = <String, double>{};
    _bodyCtl.forEach((ex, c) {
      values[ex] = double.tryParse(c.text) ?? 0;
    });
    context.read<Store>().saveBody(widget.dateKey, widget.workout, values);
    setState(() => _saved = true);
    showToast(context, '맨몸운동 기록 저장됨');
  }

  void _saveGym() {
    final blocks = <String, List<GymSet>>{};
    _gymCtl.forEach((ex, list) {
      blocks[ex] = list
          .map((s) => GymSet(
                double.tryParse(s.w.text) ?? 0,
                double.tryParse(s.r.text) ?? 0,
              ))
          .toList();
    });
    context.read<Store>().saveGym(widget.dateKey, widget.workout, blocks);
    setState(() => _saved = true);
    showToast(context, '헬스 기록 저장됨');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.only(top: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isGym
                ? '무게 × 횟수를 세트별로 입력하면 총 볼륨이 자동 계산됩니다'
                : '오늘 한 만큼 입력하면 월간 기록에 누적됩니다',
            style: AppFonts.sans(size: 11, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 10),
          if (_isGym) ..._gymBlocks() else ..._bodyRows(),
          if (_isGym) _addExerciseButton(),
          const SizedBox(height: 5),
          _SaveButton(onTap: _isGym ? _saveGym : _saveBody),
          if (_saved)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('✓ 저장됨',
                  textAlign: TextAlign.center,
                  style: AppFonts.sans(
                      size: 11, color: AppColors.done, weight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ---------- 맨몸운동 ----------
  List<Widget> _bodyRows() {
    final store = context.read<Store>();
    return widget.workout.log.map((exKey) {
      final m = store.bodyMeta(exKey);
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.sans(size: 12, color: AppColors.inkDim)),
            ),
            const SizedBox(width: 8),
            Expanded(child: _numField(_bodyCtl[exKey]!, '0', AppColors.accent)),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(m.unit,
                  style: AppFonts.sans(size: 11, color: AppColors.inkFaint)),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ---------- 헬스 ----------
  List<Widget> _gymBlocks() {
    return _exNames.map((exName) {
      final ctls = _gymCtl[exName]!;
      double vol = 0;
      for (final s in ctls) {
        vol += (double.tryParse(s.w.text) ?? 0) * (double.tryParse(s.r.text) ?? 0);
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sans(
                          size: 12.5,
                          color: AppColors.ink,
                          weight: FontWeight.w600)),
                ),
                if (vol > 0) ...[
                  const SizedBox(width: 8),
                  Text('볼륨 ${comma(vol)}kg',
                      style: AppFonts.sans(
                          size: 10.5,
                          color: AppColors.accentSoft,
                          weight: FontWeight.w600)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < ctls.length; i++)
              _setRow(exName, i, ctls[i]),
            GestureDetector(
              onTap: () => setState(() {
                _gymCtl[exName]!.add(_SetCtl(
                    w: TextEditingController(), r: TextEditingController()));
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('+ 세트 추가',
                    style: AppFonts.sans(
                        size: 11,
                        color: AppColors.accentSoft,
                        weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _addExerciseButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: GestureDetector(
        onTap: _showAddExercise,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text('+ 종목 추가',
              style: AppFonts.sans(
                  size: 12,
                  color: AppColors.accentSoft,
                  weight: FontWeight.w600)),
        ),
      ),
    );
  }

  /// 종목을 화면에 추가하고, 프로필이 있으면 그 요일 루틴에 영속화한다.
  void _addExercise(String raw) {
    final name = raw.trim();
    if (name.isEmpty || _exNames.contains(name)) return;
    final store = context.read<Store>();
    final d = DateTime.tryParse(widget.dateKey);
    if (d != null) store.addGymExerciseForDate(d, name);
    setState(() {
      _addGymCtl(name);
      _exNames.add(name);
    });
  }

  Future<void> _showAddExercise() async {
    final ctl = TextEditingController();
    // 그 날 분할 부위에 맞는 종목만 추천한다.
    const prefix = '헬스 · ';
    final name = widget.workout.name;
    final label = name.startsWith(prefix) ? name.substring(prefix.length) : name;
    final pool = SplitTemplates
        .suggestionsFor(label: label, current: _exNames)
        .where((e) => !_exNames.contains(e))
        .toList();
    void commit(String v) {
      _addExercise(v);
      Navigator.pop(context);
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: 18 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('종목 추가',
                style: AppFonts.sans(
                    size: 15, color: AppColors.ink, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: ctl,
                  autofocus: true,
                  style: AppFonts.sans(size: 13, color: AppColors.ink),
                  textInputAction: TextInputAction.done,
                  onSubmitted: commit,
                  inputFormatters: [LengthLimitingTextInputFormatter(24)],
                  decoration: inputDecoration('종목 이름'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => commit(ctl.text),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gym,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('추가',
                      style: AppFonts.sans(
                          size: 13,
                          color: AppColors.bg,
                          weight: FontWeight.w700)),
                ),
              ),
            ]),
            if (pool.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('빠른 추가',
                  style: AppFonts.sans(size: 11.5, color: AppColors.inkFaint)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final e in pool)
                        GestureDetector(
                          onTap: () => commit(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.panel2,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('+ $e',
                                style: AppFonts.sans(
                                    size: 11.5, color: AppColors.inkDim)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    ctl.dispose();
  }

  Widget _setRow(String ex, int i, _SetCtl ctl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('${i + 1}세트',
                style: AppFonts.sans(size: 10, color: AppColors.inkFaint)),
          ),
          Expanded(child: _numField(ctl.w, 'kg', AppColors.gym, decimal: true, center: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('×', style: AppFonts.sans(size: 11, color: AppColors.inkFaint)),
          ),
          Expanded(child: _numField(ctl.r, '회', AppColors.gym, center: true)),
          GestureDetector(
            onTap: () {
              final list = _gymCtl[ex]!;
              if (list.length > 1) {
                setState(() {
                  list[i].w.dispose();
                  list[i].r.dispose();
                  list.removeAt(i);
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text('×',
                  style: AppFonts.sans(size: 15, color: AppColors.inkFaint)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String hint, Color focus,
      {bool decimal = false, bool center = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) => setState(() {}),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: AppFonts.sans(size: 13, color: AppColors.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppFonts.sans(size: 12.5, color: AppColors.inkFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: AppColors.panel2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: focus),
        ),
      ),
    );
  }
}

class _SetCtl {
  final TextEditingController w;
  final TextEditingController r;
  _SetCtl({required this.w, required this.r});
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panel2,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text('기록 저장',
            style: AppFonts.sans(
                size: 12.5, color: AppColors.ink, weight: FontWeight.w600)),
      ),
    );
  }
}
