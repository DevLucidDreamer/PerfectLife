import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../date_util.dart';
import '../fonts.dart';
import '../onboarding/onboarding_screen.dart';
import '../pwa/install_prompt.dart';
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

  @override
  void initState() {
    super.initState();
    // 웹 브라우저 접속 시 PWA 설치 유도 팝업(설치 가능할 때만).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowInstallPrompt(context);
    });
  }

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
                onTap: () => showOptionsSheet(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.more_horiz,
                      size: 20, color: AppColors.inkFaint),
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

/// 설정(옵션) 시트 — 이름 변경 · 루틴 편집 · 전체 초기화.
void showOptionsSheet(BuildContext context) {
  final store = context.read<Store>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Text('옵션',
                      style: AppFonts.sans(
                          size: 13,
                          color: AppColors.inkFaint,
                          weight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
            _OptionRow(
              icon: Icons.badge_outlined,
              label: '이름 변경',
              sub: store.userName.isEmpty ? '미설정' : store.userName,
              onTap: () {
                Navigator.pop(sheetCtx);
                _showNameDialog(context);
              },
            ),
            _OptionRow(
              icon: Icons.tune,
              label: '루틴 편집',
              sub: '운동 · 독서 · 공부 · 취미 다시 설정',
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                );
              },
            ),
            _OptionRow(
              icon: Icons.delete_outline,
              label: '전체 초기화',
              sub: '모든 기록과 루틴을 삭제합니다',
              danger: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmResetAll(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 이름 변경 다이얼로그.
void _showNameDialog(BuildContext context) {
  final store = context.read<Store>();
  final ctl = TextEditingController(text: store.userName);
  showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('이름 변경',
          style: AppFonts.sans(
              size: 16, color: AppColors.ink, weight: FontWeight.w700)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        style: AppFonts.sans(size: 14, color: AppColors.ink),
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(20)],
        decoration: inputDecoration('예: 이재원'),
        onSubmitted: (_) {
          store.setUserName(ctl.text);
          Navigator.pop(dctx);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx),
          child: Text('취소', style: AppFonts.sans(color: AppColors.inkDim)),
        ),
        TextButton(
          onPressed: () {
            store.setUserName(ctl.text);
            Navigator.pop(dctx);
            showToast(context, '이름을 저장했습니다');
          },
          child: Text('저장',
              style: AppFonts.sans(
                  color: AppColors.accentSoft, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// 전체 초기화 — 2단계 확인 후 모든 데이터를 삭제하고 온보딩으로 돌아간다.
Future<void> _confirmResetAll(BuildContext context) async {
  final store = context.read<Store>();
  final ok = await confirmDialog(
    context,
    '모든 기록(운동·독서·공부·체크)과 루틴 설정이 영구히 삭제되고 처음 화면으로 돌아갑니다. 계속하시겠습니까?',
  );
  if (!ok) return;
  await store.resetAll();
  // 프로필이 비워지면 _RootGate가 온보딩을 다시 띄운다. 위에 쌓인 라우트만 정리.
  if (context.mounted) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    showToast(context, '모든 기록을 초기화했습니다');
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool danger;
  final VoidCallback onTap;
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFD96A5A) : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 21, color: danger ? color : AppColors.accentSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppFonts.sans(
                          size: 14.5,
                          color: color,
                          weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppFonts.sans(size: 11.5, color: AppColors.inkFaint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
