import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../fonts.dart';
import '../models.dart';
import '../onboarding/routine_profile.dart';
import '../store.dart';
import '../widgets/common.dart';

class ReadingTab extends StatefulWidget {
  const ReadingTab({super.key});

  @override
  State<ReadingTab> createState() => _ReadingTabState();
}

class _ReadingTabState extends State<ReadingTab> {
  bool _showAdd = false;
  final _title = TextEditingController();
  final _total = TextEditingController();
  final _start = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _start.dispose();
    super.dispose();
  }

  void _addBook() {
    final store = context.read<Store>();
    final t = _title.text.trim();
    final total = int.tryParse(_total.text) ?? 0;
    final start = int.tryParse(_start.text) ?? 0;
    if (t.isEmpty) {
      showToast(context, '책 제목을 입력하십시오');
      return;
    }
    if (total <= 0) {
      showToast(context, '총 페이지 수를 입력하십시오');
      return;
    }
    store.addBook(t, total, start);
    _title.clear();
    _total.clear();
    _start.clear();
    setState(() => _showAdd = false);
    showToast(context, '책이 추가되었습니다');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final reading = store.data.books.where((b) => !b.done).toList();
    final finished = store.data.books.where((b) => b.done).toList();
    final ordered = [...reading, ...finished];

    final plan = store.readingPlan;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        if (plan != null && plan.effectivePagesPerDay > 0) _GoalBanner(plan: plan),
        SectionTitle('독서 중인 책', meta: '읽는 중 ${reading.length} · 완독 ${finished.length}'),
        _OpenAddButton(
          label: '+ 새 책 추가',
          onTap: () => setState(() => _showAdd = !_showAdd),
        ),
        if (_showAdd) _addBox(),
        if (store.data.books.isEmpty)
          const EmptyStat('아직 등록된 책이 없습니다.\n+ 새 책 추가로 시작하십시오.')
        else
          for (final b in ordered) _BookCard(book: b),
      ],
    );
  }

  Widget _addBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _input(_title, '책 제목'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _input(_total, '총 페이지', number: true)),
            const SizedBox(width: 8),
            Expanded(child: _input(_start, '현재 페이지(선택)', number: true)),
          ]),
          const SizedBox(height: 8),
          _AddButton(label: '추가하기', onTap: _addBook),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {bool number = false}) {
    return TextField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: AppFonts.sans(size: 13, color: AppColors.ink),
      decoration: inputDecoration(hint),
    );
  }
}

/// 온보딩에서 정한 독서 목표 + 연간 예측 배너.
class _GoalBanner extends StatelessWidget {
  final ReadingPlan plan;
  const _GoalBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('나의 독서 목표',
                  style: AppFonts.sans(
                      size: 12,
                      color: AppColors.inkFaint,
                      weight: FontWeight.w600)),
              const Spacer(),
              Pill(
                  plan.daysPerWeek >= 7
                      ? plan.taskName.replaceFirst('독서 · ', '')
                      : '${plan.freqLabel} · ${plan.taskName.replaceFirst('독서 · ', '')}',
                  AppColors.accent),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _box('한 달', '${plan.booksPerMonth.toStringAsFixed(1)}권')),
            const SizedBox(width: 10),
            Expanded(child: _box('1년', '${plan.booksPerYear.toStringAsFixed(0)}권')),
          ]),
        ],
      ),
    );
  }

  Widget _box(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.sans(size: 11, color: AppColors.inkFaint)),
          const SizedBox(height: 3),
          Text(value, style: AppFonts.display(size: 20, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _BookCard extends StatefulWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  late TextEditingController _pageCtl;
  late double _sliderVal;

  @override
  void initState() {
    super.initState();
    _pageCtl = TextEditingController(text: widget.book.current.toString());
    _sliderVal = widget.book.current.toDouble();
  }

  @override
  void didUpdateWidget(_BookCard old) {
    super.didUpdateWidget(old);
    if (old.book.current != widget.book.current) {
      _pageCtl.text = widget.book.current.toString();
      _sliderVal = widget.book.current.toDouble();
    }
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  void _commit(int page) {
    final res = context.read<Store>().updatePage(widget.book.id, page);
    showToast(context, res.message);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final pct = b.total > 0 ? (b.current / b.total * 100).round().clamp(0, 100) : 0;
    final stripeColor = b.done ? AppColors.done : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: stripeColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(b.title,
                                        style: AppFonts.sans(
                                            size: 14.5,
                                            color: AppColors.ink,
                                            weight: FontWeight.w700)),
                                  ),
                                  if (b.done) ...[
                                    const SizedBox(width: 8),
                                    const Pill('완독', AppColors.done),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${b.current} / ${b.total} 페이지 · $pct%',
                                  style: AppFonts.sans(
                                      size: 11.5, color: AppColors.inkDim)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final store = context.read<Store>();
                            final ok = await confirmDialog(
                                context, '이 책을 삭제하시겠습니까?');
                            if (ok) store.deleteBook(b.id);
                          },
                          child: Text('×',
                              style: AppFonts.sans(
                                  size: 16, color: AppColors.inkFaint)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(pct: pct, done: b.done),
                    if (!b.done) ...[
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.accent,
                          inactiveTrackColor: AppColors.panel2,
                          thumbColor: AppColors.accent,
                          overlayShape: SliderComponentShape.noOverlay,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _sliderVal.clamp(0, b.total.toDouble()),
                          min: 0,
                          max: b.total.toDouble(),
                          onChanged: (v) => setState(() {
                            _sliderVal = v;
                            _pageCtl.text = v.round().toString();
                          }),
                          onChangeEnd: (v) => _commit(v.round()),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pageCtl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              textAlign: TextAlign.center,
                              style: AppFonts.sans(size: 13, color: AppColors.ink),
                              decoration: inputDecoration(''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('/ ${b.total}p',
                              style: AppFonts.sans(
                                  size: 12, color: AppColors.inkFaint)),
                          const SizedBox(width: 8),
                          _AddButton(
                            label: '기록',
                            compact: true,
                            onTap: () =>
                                _commit(int.tryParse(_pageCtl.text) ?? 0),
                          ),
                        ],
                      ),
                    ],
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

class _ProgressBar extends StatelessWidget {
  final int pct;
  final bool done;
  const _ProgressBar({required this.pct, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct / 100,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: done
                  ? [AppColors.done, const Color(0xFF9ED6B5)]
                  : [AppColors.accent, AppColors.accentSoft],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

// ---------- 공용 작은 위젯 ----------
class _OpenAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OpenAddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(label,
            style: AppFonts.sans(
                size: 13, color: AppColors.accentSoft, weight: FontWeight.w600)),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  const _AddButton(
      {required this.label, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? null : double.infinity,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.all(10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(compact ? 8 : 9),
        ),
        child: Text(label,
            style: AppFonts.sans(
                size: compact ? 12 : 13,
                color: AppColors.bg,
                weight: FontWeight.w700)),
      ),
    );
  }
}

