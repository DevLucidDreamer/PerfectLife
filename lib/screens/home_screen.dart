import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../date_util.dart';
import '../fonts.dart';
import '../onboarding/onboarding_screen.dart';
import '../store.dart';
import '../widgets/common.dart';
import '../widgets/share_card.dart';
import 'reading_tab.dart';
import 'stats_tab.dart';
import 'today_tab.dart';
import 'todo_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0; // 0 today, 1 reading, 2 todo, 3 stats

  static const _tabNames = ['오늘', '독서', '시험 TODO', '월간 기록'];

  void _switchTab(int i) {
    final store = context.read<Store>();
    setState(() => _tab = i);
    if (i == 0) store.resetViewDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // 푸터는 본문 Column의 고정 높이 자식으로 둔다.
      // (bottomNavigationBar에 넣으면 기기에 따라 화면 전체를 차지하는 문제가 있음)
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                _TabBar(current: _tab, onTap: _switchTab),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [
                      TodayTab(),
                      ReadingTab(),
                      TodoTab(),
                      StatsTab(),
                    ],
                  ),
                ),
                if (_tab == 0) const _TodayFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 헤더 — 태그/제목/날짜 + 연속달성 + 오늘 진행률.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final now = DateTime.now();
    final dateStr =
        '${now.month}월 ${now.day}일 ${Config.dayNames[now.weekday % 7]}요일';

    // 취미 등 optional 항목은 진행률에서 제외(강제성 없음).
    final tasks =
        store.buildTasks().where((t) => !t.optional).toList();
    final day = store.data.days[DateUtil.dkey(store.viewDate())];
    final done = tasks.where((t) => day?.checks[t.id] == true).length;
    final pct = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    final streak = store.streak();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.6, -1),
          end: Alignment(-0.6, 1),
          colors: [Color(0xFF1A1D1C), Color(0xFF101212)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TODAY I START',
                  style: AppFonts.sans(
                      size: 11,
                      color: AppColors.accentSoft,
                      weight: FontWeight.w600,
                      letterSpacing: 3)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.tune,
                      size: 18, color: AppColors.inkFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '오늘부터 '),
                TextSpan(text: '갓생', style: TextStyle(color: AppColors.accent)),
              ],
              style: AppFonts.display(size: 28, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 7),
          Text(dateStr,
              style: AppFonts.serif(size: 13, color: AppColors.inkDim)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  child: Row(
                    children: [
                      Text('🔥',
                          style: TextStyle(
                            fontSize: 22,
                            color: streak > 0 ? null : AppColors.inkFaint,
                          )),
                      const SizedBox(width: 10),
                      Flexible(child: _statLabelValue('연속 달성', '$streak', ' 일')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  child: Row(
                    children: [
                      ProgressRing(pct: pct),
                      const SizedBox(width: 10),
                      Flexible(
                          child: _statLabelValue(
                              '오늘 진행', '$done', '/${tasks.length}')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statLabelValue(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.sans(size: 10.5, color: AppColors.inkFaint)),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: value, style: AppFonts.display(size: 19, color: AppColors.ink)),
            TextSpan(
                text: unit, style: AppFonts.sans(size: 11, color: AppColors.inkDim)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final Widget child;
  const _StatBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _TabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _TabBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const names = _HomeScreenState._tabNames;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 4),
      child: Row(
        children: [
          for (int i = 0; i < names.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: current == i ? AppColors.accent : AppColors.panel,
                  border: Border.all(
                      color: current == i ? AppColors.accent : AppColors.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  names[i],
                  style: AppFonts.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: current == i ? AppColors.bg : AppColors.inkDim,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 오늘 탭 전용 하단 버튼 바.
class _TodayFooter extends StatelessWidget {
  const _TodayFooter();

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _FooterBtn(
                label: '초기화',
                color: AppColors.inkDim,
                onTap: () async {
                  final word = store.isToday ? '오늘' : '어제';
                  final ok = await confirmDialog(context,
                      '$word 체크 기록을 초기화하시겠습니까? (운동·독서 수치 기록은 유지됩니다)');
                  if (!ok) return;
                  store.resetToday();
                  if (context.mounted) showToast(context, '$word 체크를 초기화했습니다');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FooterBtn(
                label: '이미지 공유',
                color: AppColors.accentSoft,
                borderColor: AppColors.accent,
                onTap: () => showShareCard(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FooterBtn(
                label: '전체 완료',
                color: AppColors.bg,
                bg: AppColors.accent,
                borderColor: AppColors.accent,
                onTap: () {
                  store.completeAll();
                  showToast(
                      context,
                      store.isToday
                          ? '오늘 전체 완료 — 수고하셨습니다'
                          : '어제 항목을 모두 완료 처리했습니다');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  final Color? borderColor;
  final VoidCallback onTap;
  const _FooterBtn({
    required this.label,
    required this.color,
    this.bg,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg ?? AppColors.panel,
          border: Border.all(color: borderColor ?? AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppFonts.sans(size: 12.5, color: color, weight: FontWeight.w700),
        ),
      ),
    );
  }
}
