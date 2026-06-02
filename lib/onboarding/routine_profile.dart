// 온보딩 결과를 담는 사용자 루틴 프로필.
//
// 앱은 실시간 AI 호출 대신, 온보딩에서 사용자가 고른 답변을 아래 모델에
// "확정(materialize)"해 저장하고, 이후 화면은 이 프로필을 렌더링한다.
// 프로필이 없으면(기존 테스터·웹 호환 데이터) Store가 Config 기반 기본 루틴으로
// 폴백하므로 하위 호환이 유지된다.

import '../config.dart';

/// 운동 추천·분배에 쓰이는 정적 템플릿 모음.
class RoutineTemplates {
  RoutineTemplates._();

  /// 헬스 자동 추천 종목 (분할 미사용 시 기본 풀바디 루틴, 편집 가능).
  static const gymRecommended = <String>[
    '스쿼트',
    '벤치프레스',
    '데드리프트',
    '랫풀다운',
    '숄더 프레스',
    '바벨로우',
  ];

  /// 헬스 종목 선택 풀 (편집 UI에서 빠르게 추가). 부위별 종목을 모두 합친 것.
  static List<String> get gymPool => SplitTemplates.allGymExercises;

  /// 맨몸운동 자동 추천 종목 키 (Config.bodyLog 키, 편집 가능).
  static const bodyRecommended = <String>['pushup', 'squat', 'plank', 'lunge'];

  /// 맨몸운동 선택 풀 (Config.bodyLog 의 키 전체).
  static List<String> get bodyPool => Config.bodyLog.keys.toList();

  /// 주 N회 → 요일 분배 (0=일 ~ 6=토). 균형 있게 배치한다.
  static const _weekdayPlan = <int, List<int>>{
    1: [3],
    2: [1, 4],
    3: [1, 3, 5],
    4: [1, 2, 4, 5],
    5: [1, 2, 3, 4, 5],
    6: [1, 2, 3, 4, 5, 6],
    7: [0, 1, 2, 3, 4, 5, 6],
  };

  static List<int> weekdaysFor(int daysPerWeek) {
    final n = daysPerWeek.clamp(1, 7);
    return List<int>.from(_weekdayPlan[n] ?? const [1, 3, 5]);
  }

  /// 독서량 환산 상수.
  static const avgBookPages = 300; // 평균 단행본 분량 가정
  static const pagesPerHour = 30; // 가벼운 독서 속도 가정 (0.5p/분)
}

/// 부위별 헬스 종목·분할(3분할/5분할 등) 추천 템플릿.
class SplitTemplates {
  SplitTemplates._();

  /// 부위 → 대표 헬스 종목. 분할 구성과 종목 선택 풀의 원천.
  static const muscleGroups = <String, List<String>>{
    '가슴': [
      '벤치프레스',
      '인클라인 벤치프레스',
      '인클라인 덤벨 프레스',
      '체스트 프레스',
      '덤벨 플라이',
      '케이블 플라이',
      '딥스',
    ],
    '등': [
      '데드리프트',
      '랫풀다운',
      '바벨로우',
      '시티드 로우',
      '풀업',
      '티바로우',
      '원암 덤벨로우',
      '스트레이트암 풀다운',
    ],
    '어깨': [
      '숄더 프레스',
      '오버헤드 프레스',
      '사이드 레터럴 레이즈',
      '프론트 레이즈',
      '리어 델트 플라이',
      '업라이트 로우',
      '페이스 풀',
    ],
    '하체': [
      '스쿼트',
      '레그 프레스',
      '레그 익스텐션',
      '레그 컬',
      '런지',
      '루마니안 데드리프트',
      '힙 쓰러스트',
      '카프 레이즈',
    ],
    '삼두': [
      '케이블 푸쉬다운',
      '오버헤드 익스텐션',
      '라잉 트라이셉스 익스텐션',
      '클로즈그립 벤치프레스',
    ],
    '이두': [
      '덤벨 컬',
      '바벨 컬',
      '해머 컬',
      '프리처 컬',
      '인클라인 덤벨 컬',
    ],
    '복근': [
      '크런치',
      '행잉 레그 레이즈',
      '케이블 크런치',
      '플랭크',
      '러시안 트위스트',
    ],
    '유산소': [
      '트레드밀',
      '사이클',
      '로잉 머신',
      '스텝밀',
    ],
  };

  /// 부위 순서(라벨 정렬·분할 구성용).
  static const muscleOrder = <String>[
    '가슴', '등', '어깨', '하체', '이두', '삼두', '복근', '유산소',
  ];

  /// 모든 헬스 종목(중복 제거, 부위 순서 유지).
  static List<String> get allGymExercises {
    final seen = <String>{};
    final out = <String>[];
    for (final g in muscleOrder) {
      for (final e in muscleGroups[g] ?? const <String>[]) {
        if (seen.add(e)) out.add(e);
      }
    }
    return out;
  }

  /// 특정 종목이 속한 부위(없으면 '기타').
  static String groupOf(String exercise) {
    for (final entry in muscleGroups.entries) {
      if (entry.value.contains(exercise)) return entry.key;
    }
    return '기타';
  }

  /// 분할 하루(라벨 + 현재 담긴 종목)에 어울리는 추천 종목 풀.
  /// 라벨의 부위명과 이미 담긴 종목의 부위를 합쳐 그 부위 종목만 돌려준다.
  /// 부위를 전혀 못 찾으면(전신 등) 전체 풀을 반환한다.
  static List<String> suggestionsFor({
    required String label,
    required List<String> current,
  }) {
    final groups = <String>{};
    for (final part in label.split('·').map((e) => e.trim())) {
      if (muscleGroups.containsKey(part)) groups.add(part);
    }
    for (final ex in current) {
      final g = groupOf(ex);
      if (muscleGroups.containsKey(g)) groups.add(g);
    }
    if (groups.isEmpty) return allGymExercises;
    return [
      for (final g in muscleOrder)
        if (groups.contains(g)) ...muscleGroups[g]!,
    ];
  }

  /// 분할 수 → 각 운동일의 부위 묶음. (1=전신 ~ 6=PPL 2회전)
  static const splitPresets = <int, List<List<String>>>{
    1: [
      ['가슴', '등', '하체'], // 전신
    ],
    2: [
      ['가슴', '어깨', '삼두'], // 상체 (미는 힘)
      ['등', '이두', '하체'], // 하체+당기는 힘
    ],
    3: [
      ['가슴', '삼두'],
      ['등', '이두'],
      ['하체', '어깨', '복근'],
    ],
    4: [
      ['가슴', '삼두'],
      ['등', '이두'],
      ['어깨', '복근'],
      ['하체'],
    ],
    5: [
      ['가슴'],
      ['등'],
      ['어깨'],
      ['하체'],
      ['이두', '삼두'],
    ],
    6: [
      ['가슴', '어깨', '삼두'],
      ['등', '이두'],
      ['하체', '복근'],
      ['가슴', '어깨', '삼두'],
      ['등', '이두'],
      ['하체', '복근'],
    ],
  };

  /// 선택 가능한 분할 수 목록.
  static List<int> get availableSplits => splitPresets.keys.toList()..sort();

  /// 주 N회에 어울리는 추천 분할 수.
  static int recommendedSplitCount(int daysPerWeek) => daysPerWeek.clamp(1, 6);

  /// 분할 수에 맞는 분할 시퀀스(순서가 있는 SplitDay 목록)를 만든다.
  /// 1분할은 전신, N분할은 부위별. 헬스 세션마다 이 순서대로 순환 적용한다.
  static List<SplitDay> buildSplitDays(int splitCount, {int exPerDay = 4}) {
    final n = splitCount.clamp(1, 6);
    final preset = splitPresets[n] ?? splitPresets[3]!;
    return [
      for (final groups in preset)
        SplitDay(
          label: n == 1 ? '전신' : groups.join(' · '),
          exercises: exercisesFor(groups, exPerDay: exPerDay),
        ),
    ];
  }

  /// 운동 요일을 헬스/맨몸으로 나눈다.
  /// sameDay면 모든 요일이 둘 다, 아니면 헬스/맨몸을 번갈아 배치한다.
  /// 예: 주 6회·헬스 3·격일 → 헬스 [월·수·금], 맨몸 [화·목·토].
  static (List<int>, List<int>) assignGymBody({
    required List<int> weekdays,
    required int gymCount,
    required bool sameDay,
  }) {
    final sorted = [...weekdays]..sort();
    if (sameDay) return (List<int>.from(sorted), List<int>.from(sorted));
    final total = sorted.length;
    var g = gymCount.clamp(0, total);
    var b = total - g;
    final seq = <bool>[]; // true=gym
    var next = true;
    while (g > 0 || b > 0) {
      if (next && g > 0) {
        seq.add(true);
        g--;
        next = false;
      } else if (!next && b > 0) {
        seq.add(false);
        b--;
        next = true;
      } else if (g > 0) {
        seq.add(true);
        g--;
      } else {
        seq.add(false);
        b--;
      }
    }
    final gymDays = <int>[];
    final bodyDays = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      (seq[i] ? gymDays : bodyDays).add(sorted[i]);
    }
    return (gymDays, bodyDays);
  }

  /// 부위 묶음에서 대표 종목을 골라온다(부위별로 고르게).
  static List<String> exercisesFor(List<String> groups, {int exPerDay = 4}) {
    if (groups.isEmpty) return [];
    final perGroup = (exPerDay / groups.length).ceil().clamp(1, 99);
    final out = <String>[];
    for (final g in groups) {
      final pool = muscleGroups[g] ?? const <String>[];
      out.addAll(pool.take(perGroup));
    }
    return out;
  }
}

/// 헬스 분할 하루: 부위 라벨 + 그 날 수행할 헬스 종목.
class SplitDay {
  String label; // 예: "가슴 · 삼두"
  List<String> exercises; // 헬스 종목 이름
  SplitDay({required this.label, required this.exercises});

  Map<String, dynamic> toJson() => {'label': label, 'exercises': exercises};
  factory SplitDay.fromJson(Map<String, dynamic> j) => SplitDay(
        label: j['label'] as String? ?? '',
        exercises:
            (j['exercises'] as List?)?.map((e) => e as String).toList() ?? [],
      );
}

/// 운동 계획.
///
/// 헬스/맨몸 세션을 요일에 배치하고, 헬스는 분할 시퀀스를 **날짜 기준으로 연속 순환**한다.
/// 그래서 주 헬스 횟수보다 분할 수가 많으면 남은 분할이 자연스럽게 다음 주로 이어진다.
class WorkoutPlan {
  /// 'gym' | 'body' | 'custom' 중 사용자가 고른 것들 (복수 가능).
  final List<String> types;
  final int daysPerWeek; // 주간 총 운동일 수 (요일 개수)
  final List<int> weekdays; // 0=일 ~ 6=토 (헬스/맨몸 요일의 합집합)
  final int gymCount; // 주간 헬스 횟수
  final int bodyCount; // 주간 맨몸/기타 횟수
  final bool sameDay; // 헬스+맨몸을 같은 날 함께(true) vs 격일/다른 날(false)
  final List<int> gymWeekdays; // 헬스 요일
  final List<int> bodyWeekdays; // 맨몸/기타 요일
  final List<String> gymExercises; // 분할 미사용(전신) 시 매일 동일 헬스 종목
  final List<SplitDay> splitDays; // 헬스 분할 시퀀스 (순서대로 순환)
  final List<String> bodyKeys; // 맨몸 종목 키
  final List<String> customExercises; // 기타 운동 이름 (사용자 추가)
  final String startDate; // 분할 순환 기준일 'YYYY-MM-DD'

  WorkoutPlan({
    required this.types,
    required this.daysPerWeek,
    required this.weekdays,
    int? gymCount,
    int? bodyCount,
    this.sameDay = false,
    List<int>? gymWeekdays,
    List<int>? bodyWeekdays,
    required this.gymExercises,
    List<SplitDay>? splitDays,
    required this.bodyKeys,
    required this.customExercises,
    String? startDate,
  })  : gymWeekdays = gymWeekdays ?? const [],
        bodyWeekdays = bodyWeekdays ?? const [],
        splitDays = splitDays ?? const [],
        gymCount = gymCount ?? (gymWeekdays?.length ?? 0),
        bodyCount = bodyCount ?? (bodyWeekdays?.length ?? 0),
        startDate = startDate ?? _todayKey();

  static String _todayKey() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  bool get hasGym => types.contains('gym');
  bool get hasBody => types.contains('body');
  bool get hasCustom => types.contains('custom') && customExercises.isNotEmpty;
  bool get hasSplit => hasGym && splitDays.length > 1;

  /// 기타 운동 이름 → 맨몸 로거가 쓰는 (key, 라벨/단위) 매핑.
  Map<String, BodyExercise> get customBodyMeta {
    final m = <String, BodyExercise>{};
    for (var i = 0; i < customExercises.length; i++) {
      m['c$i'] = BodyExercise(customExercises[i], '회');
    }
    return m;
  }

  /// 맨몸 세션에서 기록할 종목 키 목록 (맨몸 + 기타).
  List<String> get bodyLogKeys {
    final keys = <String>[];
    if (hasBody) {
      keys.addAll(bodyKeys.isNotEmpty ? bodyKeys : RoutineTemplates.bodyRecommended);
    }
    for (var i = 0; i < customExercises.length; i++) {
      keys.add('c$i');
    }
    return keys;
  }

  // ---- 분할 연속 순환 ----
  static DateTime _weekStart(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    return dd.subtract(Duration(days: dd.weekday % 7)); // 그 주 일요일
  }

  /// 기준일로부터 헬스 세션 일련번호 (주 경계를 넘어 연속).
  int _gymOrdinal(DateTime d) {
    final anchor = _weekStart(DateTime.tryParse(startDate) ?? DateTime.now());
    final weeks = (_weekStart(d).difference(anchor).inDays / 7).round();
    final sorted = [...gymWeekdays]..sort();
    final per = sorted.isEmpty ? 1 : sorted.length;
    var pos = sorted.indexOf(d.weekday % 7);
    if (pos < 0) pos = 0;
    return weeks * per + pos;
  }

  /// 해당 날짜에 적용할 분할 인덱스.
  int gymSplitIndexFor(DateTime d) {
    final n = splitDays.length;
    if (n <= 1) return 0;
    final o = _gymOrdinal(d);
    return ((o % n) + n) % n;
  }

  List<String> gymExercisesFor(DateTime d) {
    if (splitDays.isEmpty) {
      return gymExercises.isNotEmpty ? gymExercises : RoutineTemplates.gymRecommended;
    }
    final ex = splitDays[gymSplitIndexFor(d)].exercises;
    return ex.isNotEmpty ? ex : RoutineTemplates.gymRecommended;
  }

  String gymLabelFor(DateTime d) =>
      splitDays.isEmpty ? '' : splitDays[gymSplitIndexFor(d)].label;

  WorkoutDay _gymSession(DateTime d) {
    final label = gymLabelFor(d);
    return WorkoutDay(
      type: 'gym',
      pill: '헬스',
      name: label.isEmpty ? '헬스 · 추천 루틴' : '헬스 · $label',
      ex: gymExercisesFor(d),
    );
  }

  WorkoutDay _bodySession() {
    final String name;
    final String pill;
    if (hasBody && hasCustom) {
      name = '맨몸 · 기타 운동';
      pill = '맨몸';
    } else if (hasCustom && !hasBody) {
      name = '기타 운동 · ${customExercises.join(', ')}';
      pill = '기타';
    } else {
      name = '맨몸운동 · 추천 루틴';
      pill = '맨몸';
    }
    return WorkoutDay(type: 'body', pill: pill, name: name, log: bodyLogKeys);
  }

  /// 특정 날짜의 운동 세션들(같은 날 헬스+맨몸이면 둘 다). 없으면 빈 리스트.
  List<WorkoutDay> sessionsFor(DateTime d) {
    final dow = d.weekday % 7;
    final out = <WorkoutDay>[];
    if (hasGym && gymWeekdays.contains(dow)) out.add(_gymSession(d));
    if ((hasBody || hasCustom) && bodyWeekdays.contains(dow)) {
      out.add(_bodySession());
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'types': types,
        'daysPerWeek': daysPerWeek,
        'weekdays': weekdays,
        'gymCount': gymCount,
        'bodyCount': bodyCount,
        'sameDay': sameDay,
        'gymWeekdays': gymWeekdays,
        'bodyWeekdays': bodyWeekdays,
        'gymExercises': gymExercises,
        'splitDays': splitDays.map((e) => e.toJson()).toList(),
        'bodyKeys': bodyKeys,
        'customExercises': customExercises,
        'startDate': startDate,
      };

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) {
    List<int> ints(String key) =>
        (j[key] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    List<String> strs(String key) =>
        (j[key] as List?)?.map((e) => e as String).toList() ?? [];

    final types = strs('types');
    final weekdays = (j['weekdays'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        RoutineTemplates.weekdaysFor(3);

    // 분할 시퀀스: 신 스키마(splitDays) 우선, 없으면 구 스키마(gymSplit) 마이그레이션.
    var splitDays = (j['splitDays'] as List?)
        ?.map((e) => SplitDay.fromJson(e as Map<String, dynamic>))
        .toList();
    final legacySplit = (j['gymSplit'] as Map?)?.map(
      (k, v) => MapEntry(int.parse(k as String),
          SplitDay.fromJson(v as Map<String, dynamic>)),
    );
    if (splitDays == null && legacySplit != null && legacySplit.isNotEmpty) {
      final seen = <String>{};
      splitDays = [
        for (final k in (legacySplit.keys.toList()..sort()))
          if (seen.add(legacySplit[k]!.label)) legacySplit[k]!,
      ];
    }
    splitDays ??= [];

    // 요일 배치: 신 스키마 우선, 없으면 타입으로부터 유도.
    var gymWeekdays = ints('gymWeekdays');
    var bodyWeekdays = ints('bodyWeekdays');
    final hasGym = types.contains('gym');
    final hasBody = types.contains('body') ||
        ((j['customExercises'] as List?)?.isNotEmpty ?? false);
    final sameDay = j['sameDay'] as bool? ?? false;
    if (gymWeekdays.isEmpty && bodyWeekdays.isEmpty) {
      if (hasGym && hasBody) {
        if (sameDay) {
          gymWeekdays = [...weekdays];
          bodyWeekdays = [...weekdays];
        } else {
          final a = SplitTemplates.assignGymBody(
            weekdays: weekdays,
            gymCount: (weekdays.length / 2).ceil(),
            sameDay: false,
          );
          gymWeekdays = a.$1;
          bodyWeekdays = a.$2;
        }
      } else if (hasGym) {
        gymWeekdays = [...weekdays];
      } else {
        bodyWeekdays = [...weekdays];
      }
    }

    return WorkoutPlan(
      types: types,
      daysPerWeek: (j['daysPerWeek'] as num?)?.toInt() ?? weekdays.length,
      weekdays: weekdays,
      gymCount: (j['gymCount'] as num?)?.toInt() ?? gymWeekdays.length,
      bodyCount: (j['bodyCount'] as num?)?.toInt() ?? bodyWeekdays.length,
      sameDay: sameDay,
      gymWeekdays: gymWeekdays,
      bodyWeekdays: bodyWeekdays,
      gymExercises: strs('gymExercises'),
      splitDays: splitDays,
      bodyKeys: strs('bodyKeys'),
      customExercises: strs('customExercises'),
      startDate: j['startDate'] as String?,
    );
  }
}

/// 독서 계획.
class ReadingPlan {
  final int pagesPerDay; // 0이면 시간 기준 사용
  final int minutesPerDay; // 0이면 페이지 기준 사용

  ReadingPlan({this.pagesPerDay = 0, this.minutesPerDay = 0});

  /// 일 환산 페이지 (페이지 우선, 없으면 시간→페이지 환산).
  int get effectivePagesPerDay {
    if (pagesPerDay > 0) return pagesPerDay;
    if (minutesPerDay > 0) {
      return (minutesPerDay * RoutineTemplates.pagesPerHour / 60).round();
    }
    return 0;
  }

  double get booksPerMonth =>
      effectivePagesPerDay * 30 / RoutineTemplates.avgBookPages;
  double get booksPerYear =>
      effectivePagesPerDay * 365 / RoutineTemplates.avgBookPages;

  /// 오늘 탭 독서 항목 제목.
  String get taskName {
    if (pagesPerDay > 0) return '독서 · 하루 $pagesPerDay페이지';
    if (minutesPerDay > 0) return '독서 · 하루 $minutesPerDay분';
    return '독서';
  }

  Map<String, dynamic> toJson() =>
      {'pagesPerDay': pagesPerDay, 'minutesPerDay': minutesPerDay};

  factory ReadingPlan.fromJson(Map<String, dynamic> j) => ReadingPlan(
        pagesPerDay: (j['pagesPerDay'] as num?)?.toInt() ?? 0,
        minutesPerDay: (j['minutesPerDay'] as num?)?.toInt() ?? 0,
      );
}

/// 공부 항목: 이름 + 주간 빈도(주 N회).
///
/// daysPerWeek 7이면 매일, 그 외에는 RoutineTemplates.weekdaysFor로 요일을 분배한다.
/// 그래서 자격증(주 1회)·어학(주 3회)처럼 매일이 아닌 공부도 다룰 수 있다.
class StudyItem {
  final String name;
  final int daysPerWeek; // 1~7 (7 = 매일)
  StudyItem({required this.name, this.daysPerWeek = 7});

  /// 이 공부가 배정되는 요일들 (0=일 ~ 6=토).
  List<int> get weekdays => RoutineTemplates.weekdaysFor(daysPerWeek);

  /// 해당 날짜에 이 공부 항목이 배정되는지.
  bool scheduledOn(DateTime d) => weekdays.contains(d.weekday % 7);

  /// 빈도 라벨 ("매일" 또는 "주 N회").
  String get freqLabel => daysPerWeek >= 7 ? '매일' : '주 $daysPerWeek회';

  Map<String, dynamic> toJson() => {'name': name, 'daysPerWeek': daysPerWeek};

  /// 신 스키마({name, daysPerWeek})와 구 스키마(문자열, 매일로 간주) 모두 허용.
  factory StudyItem.fromJson(dynamic j) {
    if (j is String) return StudyItem(name: j, daysPerWeek: 7);
    final m = j as Map<String, dynamic>;
    return StudyItem(
      name: m['name'] as String? ?? '',
      daysPerWeek: (m['daysPerWeek'] as num?)?.toInt() ?? 7,
    );
  }
}

/// 사용자 루틴 프로필 전체. 온보딩 완료 시 AppData에 저장된다.
class RoutineProfile {
  final bool onboarded;
  final WorkoutPlan? workout; // 운동 미선택 시 null
  final ReadingPlan? reading; // 독서 미선택 시 null
  final List<StudyItem> study; // 공부 항목 (이름 + 주간 빈도)
  final List<String> hobby; // 취미 항목 (자유 입력)

  RoutineProfile({
    this.onboarded = false,
    this.workout,
    this.reading,
    List<StudyItem>? study,
    List<String>? hobby,
  })  : study = study ?? const [],
        hobby = hobby ?? const [];

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'workout': workout?.toJson(),
        'reading': reading?.toJson(),
        'study': study.map((e) => e.toJson()).toList(),
        'hobby': hobby,
      };

  factory RoutineProfile.fromJson(Map<String, dynamic> j) => RoutineProfile(
        onboarded: j['onboarded'] as bool? ?? false,
        workout: j['workout'] == null
            ? null
            : WorkoutPlan.fromJson(j['workout'] as Map<String, dynamic>),
        reading: j['reading'] == null
            ? null
            : ReadingPlan.fromJson(j['reading'] as Map<String, dynamic>),
        study:
            (j['study'] as List?)?.map((e) => StudyItem.fromJson(e)).toList() ??
                [],
        hobby: (j['hobby'] as List?)?.map((e) => e as String).toList() ?? [],
      );
}
