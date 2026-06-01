import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../date_util.dart';
import '../fonts.dart';
import '../store.dart';
import '../widgets/common.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final mk = DateUtil.mkey(store.statMonth);
    final s = store.monthly(mk);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        // 월 네비
        Row(
          children: [
            _MonthBtn('‹', () => store.shiftMonth(-1)),
            Expanded(
              child: Text(
                '${store.statMonth.year}년 ${store.statMonth.month}월',
                textAlign: TextAlign.center,
                style: AppFonts.display(size: 15, color: AppColors.ink),
              ),
            ),
            _MonthBtn('›', () => store.shiftMonth(1)),
          ],
        ),
        const SizedBox(height: 14),

        // 운동 요약
        const SectionTitle('운동 요약'),
        Row(children: [
          Expanded(
            child: _StatCard(
                stripe: AppColors.body,
                label: '운동한 날',
                value: '${s.workoutDays}',
                unit: ' 일'),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _StatCard(
                stripe: AppColors.gym,
                label: '헬스 총 볼륨',
                value: comma(s.totalVol),
                unit: ' kg'),
          ),
        ]),

        // 맨몸운동 누적
        const SectionTitle('맨몸운동 누적'),
        if (s.bAgg.isNotEmpty)
          _grid([
            for (final ex in s.bAgg.keys)
              _StatCard(
                stripe: AppColors.body,
                label: store.bodyMeta(ex).label,
                value: comma(s.bAgg[ex]!),
                unit: ' ${store.bodyMeta(ex).unit}',
              ),
          ])
        else
          const EmptyStat('이번 달 맨몸운동 기록이 없습니다.'),

        // 헬스 종목별 볼륨
        const SectionTitle('헬스 종목별 볼륨'),
        if (s.gAgg.isNotEmpty)
          _WideCard(
            stripe: AppColors.gym,
            rows: (s.gAgg.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((e) => _VolRow(e.key, '${comma(e.value)} kg'))
                .toList(),
          )
        else
          const EmptyStat('이번 달 헬스 기록이 없습니다.'),

        // 독서 요약
        const SectionTitle('독서 요약'),
        Row(children: [
          Expanded(
            child: _StatCard(
                stripe: AppColors.accent,
                label: '읽은 페이지',
                value: comma(s.monthPages),
                unit: ' p'),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _StatCard(
                stripe: AppColors.done,
                label: '완독한 책',
                value: '${s.finishedBooks.length}',
                unit: ' 권'),
          ),
        ]),
        if (s.finishedBooks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: _WideCard(
              stripe: AppColors.done,
              rows: s.finishedBooks
                  .map((b) => _VolRow(b.title, '${b.total}p'))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _grid(List<Widget> cards) {
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < cards.length ? 9 : 0),
        child: Row(children: [
          Expanded(child: cards[i]),
          const SizedBox(width: 9),
          Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

class _MonthBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MonthBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
            style: AppFonts.sans(size: 16, color: AppColors.ink)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color stripe;
  final String label;
  final String value;
  final String unit;
  const _StatCard({
    required this.stripe,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: stripe),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppFonts.sans(
                            size: 11, color: AppColors.inkFaint)),
                    const SizedBox(height: 3),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: value,
                          style: AppFonts.display(
                              size: 23, color: AppColors.ink)),
                      TextSpan(
                          text: unit,
                          style: AppFonts.sans(
                              size: 12, color: AppColors.inkDim)),
                    ])),
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

class _WideCard extends StatelessWidget {
  final Color stripe;
  final List<_VolRow> rows;
  const _WideCard({required this.stripe, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: stripe),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(children: rows),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolRow extends StatelessWidget {
  final String name;
  final String value;
  const _VolRow(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                style: AppFonts.sans(size: 12, color: AppColors.inkDim)),
          ),
          Text(value,
              style: AppFonts.sans(
                  size: 12, color: AppColors.accentSoft, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
