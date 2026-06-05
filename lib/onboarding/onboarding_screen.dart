import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../fonts.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'routine_profile.dart';

/// 콜드스타트 온보딩 마법사.
///
/// "갓생을 위한 루틴!" 카테고리 선택 → 선택한 영역별 세부 설정 → 요약 →
/// 템플릿 기반으로 RoutineProfile을 확정 저장한다. 실시간 AI 호출 없이,
/// 미리 정의된 템플릿 풀(RoutineTemplates)을 사용자의 선택에 따라 조합한다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  // ---- 선택 상태(드래프트) ----
  final Set<String> _categories = {}; // workout/reading/study/hobby
  // 운동
  final Set<String> _wTypes = {}; // gym/body
  final List<String> _customEx = [];
  bool _cardio = false; // 유산소도 기록할지 여부 (선택)
  int _daysPerWeek = 3;
  final List<String> _bodyKeys = [...RoutineTemplates.bodyRecommended];
  // 헬스+맨몸 병행 배치
  bool _sameDay = false; // 같은 날 함께 vs 격일(번갈아)
  int _gymCount = 2; // 격일 모드에서 주간 헬스 횟수
  // 헬스 분할 시퀀스 (1=전신 ~ 6분할), 순서대로 순환
  int _splitCount = 3;
  List<SplitDay> _splitDays = [];
  final List<TextEditingController> _splitLabelCtl = [];
  final List<TextEditingController> _splitAddCtl = [];

  bool get _hasGym => _wTypes.contains('gym');
  // 맨몸 또는 기타 운동(둘 다 맨몸 로거로 기록).
  bool get _hasBodyish => _wTypes.contains('body') || _customEx.isNotEmpty;

  /// 실제 적용될 주간 헬스 횟수.
  int get _effectiveGymCount {
    if (!_hasGym) return 0;
    if (!_hasBodyish || _sameDay) return _daysPerWeek;
    if (_daysPerWeek < 2) return _daysPerWeek; // 격일 배치 불가 → 전부 헬스
    return _gymCount.clamp(1, _daysPerWeek - 1);
  }

  /// 실제 적용될 주간 맨몸/기타 횟수.
  int get _effectiveBodyCount {
    if (!_hasBodyish) return 0;
    if (!_hasGym || _sameDay) return _daysPerWeek;
    return _daysPerWeek - _effectiveGymCount;
  }
  // 독서
  bool _readByPages = true;
  int _pagesPerDay = 20;
  int _minutesPerDay = 30;
  // 공부 / 취미
  final List<StudyItem> _study = [];
  final List<String> _hobby = [];

  // 입력 컨트롤러
  final _nameCtl = TextEditingController();
  final _customAdd = TextEditingController();
  final _gymAdd = TextEditingController();
  final _studyAdd = TextEditingController();
  final _hobbyAdd = TextEditingController();

  static const _catMeta = <String, ({String label, String emoji, String desc})>{
    'workout': (label: '운동', emoji: '💪', desc: '헬스 · 맨몸운동 · 기타'),
    'reading': (label: '독서', emoji: '📖', desc: '하루 목표량으로 연간 권수 예측'),
    'study': (label: '공부', emoji: '✏️', desc: '시험 · 어학 · 자격증 등 직접 작성'),
    'hobby': (label: '취미', emoji: '🎨', desc: '꾸준히 이어갈 나만의 취미'),
  };

  @override
  void initState() {
    super.initState();
    _loadExisting();
    // 기존 분할을 불러왔으면 그대로 두고, 없으면 헬스 횟수에 맞춰 새로 추천한다.
    if (_splitDays.isEmpty) {
      _splitCount = SplitTemplates.recommendedSplitCount(_effectiveGymCount);
      _regenSplit();
    } else {
      _ensureSplitControllers();
    }
  }

  /// 이미 온보딩한 사용자가 설정을 다시 열면 기존 프로필을 드래프트로 불러온다.
  void _loadExisting() {
    _nameCtl.text = context.read<Store>().userName;
    final p = context.read<Store>().profile;
    if (p == null || !p.onboarded) return;
    final wp = p.workout;
    if (wp != null) {
      _categories.add('workout');
      if (wp.hasGym) _wTypes.add('gym');
      if (wp.hasBody) _wTypes.add('body');
      _daysPerWeek = wp.daysPerWeek;
      _cardio = wp.cardio;
      _sameDay = wp.sameDay;
      if (wp.gymCount > 0) _gymCount = wp.gymCount;
      if (wp.bodyKeys.isNotEmpty) {
        _bodyKeys
          ..clear()
          ..addAll(wp.bodyKeys);
      }
      _customEx.addAll(wp.customExercises);
      if (wp.splitDays.isNotEmpty) {
        _splitDays = wp.splitDays
            .map((e) => SplitDay(label: e.label, exercises: [...e.exercises]))
            .toList();
        _splitCount = _splitDays.length;
      } else if (wp.gymExercises.isNotEmpty) {
        _splitDays = [SplitDay(label: '전신', exercises: [...wp.gymExercises])];
        _splitCount = 1;
      }
    }
    final rp = p.reading;
    if (rp != null) {
      _categories.add('reading');
      if (rp.pagesPerDay > 0) {
        _readByPages = true;
        _pagesPerDay = rp.pagesPerDay;
      } else if (rp.minutesPerDay > 0) {
        _readByPages = false;
        _minutesPerDay = rp.minutesPerDay;
      }
    }
    if (p.study.isNotEmpty) {
      _categories.add('study');
      _study.addAll(p.study);
    }
    if (p.hobby.isNotEmpty) {
      _categories.add('hobby');
      _hobby.addAll(p.hobby);
    }
  }

  /// 헬스/맨몸 횟수·빈도가 바뀌면 헬스 횟수에 맞춰 분할 수를 다시 추천한다.
  void _recommendSplit() {
    _gymCount = _gymCount.clamp(1, (_daysPerWeek - 1).clamp(1, 6));
    _splitCount = SplitTemplates.recommendedSplitCount(_effectiveGymCount);
    _regenSplit();
  }

  /// 현재 분할 수로 분할 시퀀스를 새로 만든다(수동 편집은 초기화).
  void _regenSplit() {
    _splitDays = SplitTemplates.buildSplitDays(_splitCount);
    _ensureSplitControllers();
  }

  /// 분할 개수에 맞는 라벨/입력 컨트롤러를 준비하고 라벨 텍스트를 동기화한다.
  void _ensureSplitControllers() {
    while (_splitLabelCtl.length < _splitDays.length) {
      _splitLabelCtl.add(TextEditingController());
      _splitAddCtl.add(TextEditingController());
    }
    for (var i = 0; i < _splitDays.length; i++) {
      _splitLabelCtl[i].text = _splitDays[i].label;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _customAdd.dispose();
    _gymAdd.dispose();
    _studyAdd.dispose();
    _hobbyAdd.dispose();
    for (final c in _splitLabelCtl) {
      c.dispose();
    }
    for (final c in _splitAddCtl) {
      c.dispose();
    }
    super.dispose();
  }

  /// 현재 선택에 따른 단계 흐름.
  List<String> get _flow => [
        'intro',
        if (_categories.contains('workout')) 'workout',
        if (_categories.contains('reading')) 'reading',
        if (_categories.contains('study')) 'study',
        if (_categories.contains('hobby')) 'hobby',
        'summary',
      ];

  String get _current {
    final f = _flow;
    return f[_step.clamp(0, f.length - 1)];
  }

  bool get _canNext {
    switch (_current) {
      case 'intro':
        return _categories.isNotEmpty;
      case 'workout':
        return _wTypes.isNotEmpty || _customEx.isNotEmpty;
      case 'reading':
        return _effectivePages > 0;
      default:
        return true;
    }
  }

  int get _effectivePages =>
      _readByPages ? _pagesPerDay : (_minutesPerDay * RoutineTemplates.pagesPerHour ~/ 60);

  void _next() {
    if (_current == 'summary') {
      _finish();
      return;
    }
    if (!_canNext) return;
    setState(() => _step = (_step + 1).clamp(0, _flow.length - 1));
  }

  void _back() {
    if (_step == 0) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      return;
    }
    setState(() => _step = _step - 1);
  }

  RoutineProfile _buildProfile() {
    WorkoutPlan? wp;
    if (_categories.contains('workout')) {
      final types = <String>[];
      if (_hasGym) types.add('gym');
      if (_wTypes.contains('body')) types.add('body');
      if (_customEx.isNotEmpty) types.add('custom');
      final weekdays = RoutineTemplates.weekdaysFor(_daysPerWeek)..sort();
      final assign = SplitTemplates.assignGymBody(
        weekdays: weekdays,
        gymCount: _effectiveGymCount,
        sameDay: _sameDay,
      );
      wp = WorkoutPlan(
        types: types.isEmpty ? ['gym'] : types,
        daysPerWeek: _daysPerWeek,
        weekdays: weekdays,
        gymCount: _effectiveGymCount,
        bodyCount: _effectiveBodyCount,
        sameDay: _sameDay,
        gymWeekdays: _hasGym ? assign.$1 : const [],
        bodyWeekdays: _hasBodyish ? assign.$2 : const [],
        gymExercises: const [],
        splitDays: _hasGym
            ? _splitDays
                .map((e) =>
                    SplitDay(label: e.label, exercises: List.from(e.exercises)))
                .toList()
            : const [],
        bodyKeys: _wTypes.contains('body') ? List.from(_bodyKeys) : const [],
        customExercises: List.from(_customEx),
        cardio: _cardio,
      );
    }
    ReadingPlan? rp;
    if (_categories.contains('reading')) {
      rp = ReadingPlan(
        pagesPerDay: _readByPages ? _pagesPerDay : 0,
        minutesPerDay: _readByPages ? 0 : _minutesPerDay,
      );
    }
    return RoutineProfile(
      onboarded: true,
      workout: wp,
      reading: rp,
      study: _categories.contains('study') ? [..._study] : const [],
      hobby: _categories.contains('hobby') ? List.from(_hobby) : [],
    );
  }

  void _finish() {
    final store = context.read<Store>();
    store.data.userName = _nameCtl.text.trim();
    store.saveProfile(_buildProfile());
    // 토스트는 라우트를 닫기 전에 띄운다(앱 레벨 ScaffoldMessenger에 표시되어 유지됨).
    showToast(context, '갓생 루틴이 준비됐습니다 — 오늘부터 시작!');
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final total = flow.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _progressHeader(_step + 1, total),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: _stepContent(),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== 상단 =====================
  Widget _progressHeader(int cur, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP $cur / $total',
              style: AppFonts.sans(
                  size: 11,
                  color: AppColors.accentSoft,
                  weight: FontWeight.w600,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cur / total,
              minHeight: 5,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 단계별 본문 =====================
  List<Widget> _stepContent() {
    switch (_current) {
      case 'workout':
        return _workoutStep();
      case 'reading':
        return _readingStep();
      case 'study':
        return _studyStep();
      case 'hobby':
        return _listStep(
          emoji: '🎨',
          title: '취미',
          hint: '예: 기타 연습 20분, 그림 1장, 일기 쓰기',
          items: _hobby,
          ctl: _hobbyAdd,
        );
      case 'summary':
        return _summaryStep();
      case 'intro':
      default:
        return _introStep();
    }
  }

  // ---- intro ----
  List<Widget> _introStep() {
    return [
      const SizedBox(height: 4),
      Text('갓생을 위한 루틴!',
          style: AppFonts.display(size: 30, color: AppColors.ink)),
      const SizedBox(height: 10),
      Text('이어가고 싶은 영역을 골라주세요. 선택에 맞춰 루틴을 자동으로 짜드립니다. (복수 선택 가능)',
          style: AppFonts.serif(size: 13.5, color: AppColors.inkDim)),
      const SizedBox(height: 18),
      _label('이름 (운동 기록 공유에 표시됩니다)'),
      TextField(
        controller: _nameCtl,
        style: AppFonts.sans(size: 14, color: AppColors.ink),
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(20)],
        decoration: inputDecoration('예: 이재원'),
      ),
      const SizedBox(height: 18),
      for (final e in _catMeta.entries)
        _bigSelectCard(
          emoji: e.value.emoji,
          label: e.value.label,
          desc: e.value.desc,
          selected: _categories.contains(e.key),
          onTap: () => setState(() {
            if (!_categories.add(e.key)) _categories.remove(e.key);
          }),
        ),
    ];
  }

  // ---- 운동 ----
  List<Widget> _workoutStep() {
    final weekdays = RoutineTemplates.weekdaysFor(_daysPerWeek)..sort();
    final dayLabels = weekdays.map((d) => Config.dayNames[d]).join(' · ');
    return [
      _stepTitle('💪', '운동 설정'),
      _label('어떤 운동을 하시겠어요? (복수 선택)'),
      Row(children: [
        Expanded(
          child: _toggleChip('헬스', _hasGym, AppColors.gym, () {
            setState(() {
              if (!_wTypes.add('gym')) _wTypes.remove('gym');
              _recommendSplit();
            });
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _toggleChip('맨몸운동', _wTypes.contains('body'), AppColors.body,
              () {
            setState(() {
              if (!_wTypes.add('body')) _wTypes.remove('body');
              _recommendSplit();
            });
          }),
        ),
      ]),
      const SizedBox(height: 16),
      _label('기타 운동 (직접 추가 — 수영, 클라이밍 등)'),
      _editableChips(
        items: _customEx,
        ctl: _customAdd,
        color: AppColors.accent,
        hint: '기타 운동 이름',
      ),
      const SizedBox(height: 16),
      _label('유산소도 기록할까요?'),
      _toggleChip(
        _cardio ? '유산소 기록함 (선택)' : '유산소는 안 할래요',
        _cardio,
        AppColors.accent,
        () => setState(() => _cardio = !_cardio),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('켜두면 오늘 탭에 유산소 기록 칸이 나타나요. 매일 강제하진 않아요.',
            style: AppFonts.serif(size: 12.5, color: AppColors.inkFaint)),
      ),
      const SizedBox(height: 16),
      _label('주 몇 회 진행할까요?'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int n = 1; n <= 7; n++)
            _freqChip(n, _daysPerWeek == n, () => setState(() {
                  _daysPerWeek = n;
                  _recommendSplit();
                })),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('운동 요일: $dayLabels',
            style: AppFonts.sans(size: 12, color: AppColors.inkFaint)),
      ),
      if (_hasGym && _hasBodyish) ..._combineSection(weekdays),
      if (_hasGym) ..._gymSplitSection(),
      if (_wTypes.contains('body')) ...[
        const SizedBox(height: 18),
        _label('맨몸운동 종목 (탭하여 추가/제거)'),
        _bodyKeyPicker(),
      ],
    ];
  }

  // ---- 헬스 + 맨몸 병행 배치 ----
  List<Widget> _combineSection(List<int> weekdays) {
    return [
      const SizedBox(height: 18),
      _label('헬스와 맨몸운동을 어떻게 배치할까요?'),
      Row(children: [
        Expanded(
          child: _toggleChip('격일 (번갈아)', !_sameDay, AppColors.gym, () {
            setState(() {
              _sameDay = false;
              _recommendSplit();
            });
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _toggleChip('같은 날 함께', _sameDay, AppColors.gym, () {
            setState(() {
              _sameDay = true;
              _recommendSplit();
            });
          }),
        ),
      ]),
      if (!_sameDay) ...[
        const SizedBox(height: 14),
        _label('주 $_daysPerWeek회 중 헬스는 몇 회?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int g = 1; g <= _daysPerWeek - 1; g++)
              _freqChip(g, _effectiveGymCount == g, () => setState(() {
                    _gymCount = g;
                    _splitCount = SplitTemplates.recommendedSplitCount(
                        _effectiveGymCount);
                    _regenSplit();
                  })),
          ],
        ),
      ],
      const SizedBox(height: 12),
      _dayAssignmentPreview(weekdays),
    ];
  }

  /// 요일별 헬스/맨몸 배치 미리보기.
  Widget _dayAssignmentPreview(List<int> weekdays) {
    final assign = SplitTemplates.assignGymBody(
      weekdays: weekdays,
      gymCount: _effectiveGymCount,
      sameDay: _sameDay,
    );
    final gymSet = assign.$1.toSet();
    final bodySet = assign.$2.toSet();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final d in weekdays)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(children: [
                SizedBox(
                  width: 22,
                  child: Text(Config.dayNames[d],
                      style: AppFonts.sans(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.ink)),
                ),
                const SizedBox(width: 10),
                if (_hasGym && gymSet.contains(d)) ...[
                  Pill('헬스', AppColors.gym),
                  const SizedBox(width: 6),
                ],
                if (_hasBodyish && bodySet.contains(d))
                  Pill('맨몸', AppColors.body),
              ]),
            ),
        ],
      ),
    );
  }

  // ---- 헬스 분할 구성 ----
  List<Widget> _gymSplitSection() {
    final rec = SplitTemplates.recommendedSplitCount(_effectiveGymCount);
    final carry = _splitCount > _effectiveGymCount && _effectiveGymCount > 0;
    return [
      const SizedBox(height: 18),
      _label('헬스 분할'),
      Text(
        '주 헬스 $_effectiveGymCount회에는 ${_splitLabelForCount(rec)}이 잘 맞아요.'
        '${carry ? ' 분할이 헬스 횟수보다 많아 남은 분할은 다음 주로 이어집니다.' : ''}',
        style: AppFonts.serif(size: 12.5, color: AppColors.inkDim),
      ),
      const SizedBox(height: 12),
      _label('분할 방식'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final n in SplitTemplates.availableSplits) _splitCountChip(n),
        ],
      ),
      const SizedBox(height: 14),
      for (int i = 0; i < _splitDays.length; i++) _splitDayEditor(i),
    ];
  }

  String _splitLabelForCount(int n) => n == 1 ? '전신(풀바디)' : '$n분할';

  Widget _splitCountChip(int n) {
    final selected = _splitCount == n;
    final recommended =
        n == SplitTemplates.recommendedSplitCount(_effectiveGymCount);
    return GestureDetector(
      onTap: () => setState(() {
        _splitCount = n;
        _regenSplit();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.gym : AppColors.panel,
          border: Border.all(color: selected ? AppColors.gym : AppColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          recommended ? '${_splitLabelForCount(n)} · 추천' : _splitLabelForCount(n),
          style: AppFonts.sans(
              size: 12.5,
              color: selected ? AppColors.bg : AppColors.inkDim,
              weight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _splitDayEditor(int i) {
    if (i >= _splitDays.length) return const SizedBox.shrink();
    final sd = _splitDays[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gym.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_splitDays.length == 1 ? '전신' : '${i + 1}일차',
                  style: AppFonts.sans(
                      size: 12,
                      color: AppColors.gym,
                      weight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _splitLabelCtl[i],
                style: AppFonts.sans(
                    size: 13.5, color: AppColors.ink, weight: FontWeight.w600),
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                onChanged: (v) => sd.label = v,
                decoration: inputDecoration('부위 (예: 가슴 · 삼두)'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _editableChips(
            items: sd.exercises,
            ctl: _splitAddCtl[i],
            color: AppColors.gym,
            hint: '종목 추가',
            pool: SplitTemplates.suggestionsFor(
                label: sd.label, current: sd.exercises),
          ),
        ],
      ),
    );
  }

  Widget _bodyKeyPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in RoutineTemplates.bodyPool)
          _toggleChip(
            Config.bodyLog[key]!.label,
            _bodyKeys.contains(key),
            AppColors.body,
            () => _toggleListItem(_bodyKeys, key),
            compact: true,
          ),
      ],
    );
  }

  // ---- 독서 ----
  List<Widget> _readingStep() {
    final pages = _effectivePages;
    final perMonth = pages * 30 / RoutineTemplates.avgBookPages;
    final perYear = pages * 365 / RoutineTemplates.avgBookPages;
    return [
      _stepTitle('📖', '독서 목표'),
      _label('목표 기준을 선택하세요'),
      Row(children: [
        Expanded(
          child: _toggleChip('하루 페이지', _readByPages, AppColors.accent,
              () => setState(() => _readByPages = true)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _toggleChip('하루 시간', !_readByPages, AppColors.accent,
              () => setState(() => _readByPages = false)),
        ),
      ]),
      const SizedBox(height: 16),
      if (_readByPages)
        _stepper(
          label: '하루 목표',
          value: _pagesPerDay,
          unit: '페이지',
          step: 5,
          min: 5,
          max: 300,
          onChanged: (v) => setState(() => _pagesPerDay = v),
        )
      else
        _stepper(
          label: '하루 목표',
          value: _minutesPerDay,
          unit: '분',
          step: 10,
          min: 10,
          max: 480,
          onChanged: (v) => setState(() => _minutesPerDay = v),
        ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 속도라면…',
                style: AppFonts.sans(
                    size: 12, color: AppColors.inkFaint, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (!_readByPages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('하루 약 $pages페이지 (시간당 ${RoutineTemplates.pagesPerHour}p 기준)',
                    style: AppFonts.sans(size: 12.5, color: AppColors.inkDim)),
              ),
            Row(children: [
              Expanded(child: _projBox('한 달', perMonth)),
              const SizedBox(width: 10),
              Expanded(child: _projBox('1년', perYear)),
            ]),
            const SizedBox(height: 8),
            Text('* 단행본 평균 ${RoutineTemplates.avgBookPages}페이지 기준 예상치',
                style: AppFonts.sans(size: 10.5, color: AppColors.inkFaint)),
          ],
        ),
      ),
    ];
  }

  Widget _projBox(String label, double books) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.sans(size: 11, color: AppColors.inkFaint)),
          const SizedBox(height: 3),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: books.toStringAsFixed(books >= 10 ? 0 : 1),
                style: AppFonts.display(size: 24, color: AppColors.ink)),
            TextSpan(
                text: ' 권',
                style: AppFonts.sans(size: 12, color: AppColors.inkDim)),
          ])),
        ],
      ),
    );
  }

  // ---- 공부 (항목별 주간 빈도) ----
  List<Widget> _studyStep() {
    void add(String raw) {
      final v = raw.trim();
      if (v.isEmpty || _study.any((s) => s.name == v)) return;
      setState(() => _study.add(StudyItem(name: v, daysPerWeek: 7)));
      _studyAdd.clear();
    }

    return [
      _stepTitle('✏️', '공부 목표'),
      _label('이어갈 공부 항목을 추가하고, 주 몇 회 할지 정하세요'),
      for (int i = 0; i < _study.length; i++) _studyItemCard(i),
      if (_study.isNotEmpty) const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _studyAdd,
              style: AppFonts.sans(size: 13, color: AppColors.ink),
              textInputAction: TextInputAction.done,
              onSubmitted: add,
              inputFormatters: [LengthLimitingTextInputFormatter(24)],
              decoration: inputDecoration('예: 토익 단어 30개, 자격증 인강 1강'),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => add(_studyAdd.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
      const SizedBox(height: 12),
      Text('매일이 아니어도 괜찮아요. 자격증은 주 1회, 어학은 주 3회처럼 자유롭게 정하세요.',
          style: AppFonts.serif(size: 12.5, color: AppColors.inkFaint)),
    ];
  }

  Widget _studyItemCard(int i) {
    if (i >= _study.length) return const SizedBox.shrink();
    final s = _study[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(s.name,
                  style: AppFonts.sans(
                      size: 14, color: AppColors.ink, weight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: () => setState(() => _study.removeAt(i)),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('×',
                    style: AppFonts.sans(size: 18, color: AppColors.inkFaint)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (int n = 1; n <= 7; n++)
                _studyFreqChip(
                  n,
                  s.daysPerWeek == n,
                  () => setState(() =>
                      _study[i] = StudyItem(name: s.name, daysPerWeek: n)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studyFreqChip(int n, bool selected, VoidCallback onTap) {
    final label = n >= 7 ? '매일' : '주 $n';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.study : AppColors.panel,
          border:
              Border.all(color: selected ? AppColors.study : AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: AppFonts.sans(
                size: 12.5,
                color: selected ? AppColors.bg : AppColors.inkDim,
                weight: FontWeight.w600)),
      ),
    );
  }

  // ---- 취미 ----
  List<Widget> _listStep({
    required String emoji,
    required String title,
    required String hint,
    required List<String> items,
    required TextEditingController ctl,
  }) {
    return [
      _stepTitle(emoji, title),
      _label('매일 이어갈 항목을 자유롭게 추가하세요'),
      _editableChips(items: items, ctl: ctl, color: AppColors.hobby, hint: hint),
      const SizedBox(height: 12),
      Text('취미는 강제하지 않아요 — 완료하지 않아도 연속 일수는 유지됩니다.',
          style: AppFonts.serif(size: 12.5, color: AppColors.inkFaint)),
    ];
  }

  // ---- 요약 ----
  List<Widget> _summaryStep() {
    final p = _buildProfile();
    return [
      _stepTitle('✨', '이렇게 시작할게요'),
      if (p.workout != null) ...[
        _label('주간 운동'),
        _weeklyPreview(p),
        if (p.workout!.cardio) ...[
          const SizedBox(height: 8),
          _summaryLine('유산소', '오늘 탭에서 자유롭게 기록 (선택)'),
        ],
        const SizedBox(height: 14),
      ],
      if (p.reading != null) ...[
        _label('독서'),
        _summaryLine(p.reading!.taskName,
            '한 달 ${p.reading!.booksPerMonth.toStringAsFixed(1)}권 · 1년 ${p.reading!.booksPerYear.toStringAsFixed(0)}권'),
        const SizedBox(height: 14),
      ],
      if (p.study.isNotEmpty) ...[
        _label('공부'),
        for (final s in p.study) _summaryLine(s.name, s.freqLabel),
        const SizedBox(height: 14),
      ],
      if (p.hobby.isNotEmpty) ...[
        _label('취미'),
        for (final h in p.hobby) _summaryLine(h, null),
        const SizedBox(height: 14),
      ],
      const SizedBox(height: 4),
      Text('“완벽보다 빈도” — 최소 기준만 넘기면 오늘은 성공입니다.',
          style: AppFonts.serif(size: 13, color: AppColors.inkDim)),
    ];
  }

  Widget _weeklyPreview(RoutineProfile p) {
    final wp = p.workout!;
    // 이번 주 일요일~토요일 실제 날짜로 세션을 렌더링한다(분할 순환 반영).
    final now = DateTime.now();
    final sunday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int dow = 0; dow < 7; dow++)
            _weeklyRow(dow, wp.sessionsFor(sunday.add(Duration(days: dow)))),
        ],
      ),
    );
  }

  Widget _weeklyRow(int dow, List<WorkoutDay> sessions) {
    final isWorkout = sessions.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(Config.dayNames[dow],
                style: AppFonts.sans(
                    size: 13,
                    weight: FontWeight.w700,
                    color: isWorkout ? AppColors.ink : AppColors.inkFaint)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isWorkout ? sessions.map((s) => s.name).join('  +  ') : '휴식',
              style: AppFonts.sans(
                  size: 12.5,
                  color: isWorkout ? AppColors.inkDim : AppColors.inkFaint),
            ),
          ),
          for (final s in sessions) ...[
            const SizedBox(width: 6),
            Pill(s.pill, AppColors.forType(s.type)),
          ],
        ],
      ),
    );
  }

  Widget _summaryLine(String title, String? sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppFonts.sans(
                        size: 13.5, color: AppColors.ink, weight: FontWeight.w600)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub,
                        style: AppFonts.sans(size: 11.5, color: AppColors.inkDim)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 하단 =====================
  Widget _bottomBar() {
    final isSummary = _current == 'summary';
    // 첫 실행(되돌릴 화면이 없는 초기 설정)에서는 step 0에 '닫기'를 숨긴다.
    // 메인에서 다시 연 경우(canPop)에는 '닫기'로 빠져나갈 수 있게 둔다.
    final showBack = _step > 0 || Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            GestureDetector(
              onTap: _back,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_step == 0 ? '닫기' : '이전',
                    style: AppFonts.sans(
                        size: 13,
                        color: AppColors.inkDim,
                        weight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _canNext ? _next : null,
              child: Opacity(
                opacity: _canNext ? 1 : 0.4,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isSummary ? '갓생 루틴 시작하기' : '다음',
                      style: AppFonts.sans(
                          size: 14, color: AppColors.bg, weight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 재사용 위젯 =====================
  void _toggleListItem(List<String> list, String v) => setState(() {
        if (!list.remove(v)) list.add(v);
      });

  Widget _stepTitle(String emoji, String title) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 14),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(title, style: AppFonts.display(size: 22, color: AppColors.ink)),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 9),
        child: Text(text,
            style: AppFonts.sans(
                size: 13, color: AppColors.ink, weight: FontWeight.w600)),
      );

  Widget _bigSelectCard({
    required String emoji,
    required String label,
    required String desc,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.panel2 : AppColors.panel,
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppFonts.sans(
                          size: 16,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: AppFonts.sans(size: 12, color: AppColors.inkDim)),
                ],
              ),
            ),
            _CheckDot(selected: selected),
          ],
        ),
      ),
    );
  }

  Widget _toggleChip(String label, bool selected, Color color, VoidCallback onTap,
      {bool compact = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 13 : 14, vertical: compact ? 9 : 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.panel,
          border: Border.all(color: selected ? color : AppColors.line),
          borderRadius: BorderRadius.circular(compact ? 18 : 11),
        ),
        child: Text(label,
            style: AppFonts.sans(
                size: compact ? 12.5 : 13.5,
                color: selected ? AppColors.bg : AppColors.inkDim,
                weight: FontWeight.w600)),
      ),
    );
  }

  Widget _freqChip(int n, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.panel,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text('$n',
            style: AppFonts.display(
                size: 17, color: selected ? AppColors.bg : AppColors.inkDim)),
      ),
    );
  }

  Widget _stepper({
    required String label,
    required int value,
    required String unit,
    required int step,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Text(label, style: AppFonts.sans(size: 13, color: AppColors.inkDim)),
          const Spacer(),
          _roundBtn('−', () => onChanged((value - step).clamp(min, max))),
          SizedBox(
            width: 86,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$value',
                    style: AppFonts.display(size: 22, color: AppColors.ink)),
                TextSpan(
                    text: ' $unit',
                    style: AppFonts.sans(size: 12, color: AppColors.inkDim)),
              ]),
              textAlign: TextAlign.center,
            ),
          ),
          _roundBtn('+', () => onChanged((value + step).clamp(min, max))),
        ],
      ),
    );
  }

  Widget _roundBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panel2,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
            style: AppFonts.sans(size: 18, color: AppColors.accentSoft)),
      ),
    );
  }

  /// 칩 목록 + 입력으로 추가/삭제. pool이 있으면 빠른 추가 제안.
  Widget _editableChips({
    required List<String> items,
    required TextEditingController ctl,
    required Color color,
    required String hint,
    List<String>? pool,
  }) {
    void add(String raw) {
      final v = raw.trim();
      if (v.isEmpty || items.contains(v)) return;
      setState(() => items.add(v));
      ctl.clear();
    }

    final suggestions =
        pool?.where((e) => !items.contains(e)).take(8).toList() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final it in items)
                _removableChip(it, color, () => setState(() => items.remove(it))),
            ],
          ),
        if (items.isNotEmpty) const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctl,
                style: AppFonts.sans(size: 13, color: AppColors.ink),
                textInputAction: TextInputAction.done,
                onSubmitted: add,
                inputFormatters: [LengthLimitingTextInputFormatter(24)],
                decoration: inputDecoration(hint),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => add(ctl.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final s in suggestions)
                GestureDetector(
                  onTap: () => add(s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('+ $s',
                        style: AppFonts.sans(size: 11.5, color: AppColors.inkDim)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _removableChip(String label, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppFonts.sans(size: 12.5, color: AppColors.ink)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Text('×',
                style: AppFonts.sans(size: 15, color: AppColors.inkFaint)),
          ),
        ],
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;
  const _CheckDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        border: Border.all(
            color: selected ? AppColors.accent : AppColors.line, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: selected
          ? const Icon(Icons.check, size: 15, color: AppColors.bg)
          : null,
    );
  }
}
