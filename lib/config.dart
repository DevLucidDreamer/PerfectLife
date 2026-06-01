import 'package:flutter/material.dart';

/// 웹 버전 `Config` 객체에 대응하는 상수 모음.
class Config {
  Config._();

  static const dayNames = ['일', '월', '화', '수', '목', '금', '토'];

  /// SQLD 시험일 (8/22)
  static final sqldExam = DateTime(2026, 8, 22);

  /// 맨몸운동: 기록 가능한 종목 (key -> 라벨/단위)
  /// 앞 4개는 웹 버전 호환 종목, 이후는 온보딩 추천 풀에서 쓰는 확장 종목.
  static const bodyLog = <String, BodyExercise>{
    'pushup': BodyExercise('푸쉬업', '회'),
    'pullup': BodyExercise('풀업', '회'),
    'chinup': BodyExercise('친업', '회'),
    'plank': BodyExercise('플랭크', '분'),
    'squat': BodyExercise('맨몸 스쿼트', '회'),
    'lunge': BodyExercise('런지', '회'),
    'burpee': BodyExercise('버피', '회'),
    'dips': BodyExercise('딥스', '회'),
    'situp': BodyExercise('싯업', '회'),
    'legraise': BodyExercise('레그 레이즈', '회'),
    'crunch': BodyExercise('크런치', '회'),
    'mountainclimber': BodyExercise('마운틴 클라이머', '회'),
    'jumpingjack': BodyExercise('점핑잭', '회'),
    'wallsit': BodyExercise('월싯', '분'),
    'diamondpushup': BodyExercise('다이아몬드 푸쉬업', '회'),
    'pikepushup': BodyExercise('파이크 푸쉬업', '회'),
    'gluteridge': BodyExercise('글루트 브릿지', '회'),
    'calfraise': BodyExercise('카프 레이즈', '회'),
    'sidelplank': BodyExercise('사이드 플랭크', '분'),
    'bicyclecrunch': BodyExercise('바이시클 크런치', '회'),
  };

  /// 요일별 운동 (0=일 ~ 6=토)
  static const workout = <int, WorkoutDay>{
    1: WorkoutDay(
      type: 'gym',
      pill: '헬스',
      name: '헬스 · 등 · 삼두 · 유산소',
      ex: [
        '랫풀다운',
        '시티드 로우',
        '바벨로우',
        '어시스트 풀업',
        '케이블 푸쉬다운',
        '오버헤드 익스텐션',
      ],
    ),
    2: WorkoutDay(
      type: 'body',
      pill: '맨몸 A',
      name: '맨몸운동 A · 미는 힘',
      log: ['pushup', 'plank'],
    ),
    3: WorkoutDay(
      type: 'gym',
      pill: '헬스',
      name: '헬스 · 가슴 · 이두 · 유산소',
      ex: [
        '벤치프레스',
        '체스트 프레스',
        '인클라인 덤벨 프레스',
        '덤벨 컬',
        '바이셉스 컬',
        '바벨 컬',
      ],
    ),
    4: WorkoutDay(
      type: 'body',
      pill: '맨몸 B',
      name: '맨몸운동 B · 당기는 힘',
      log: ['pullup', 'chinup', 'plank'],
    ),
    5: WorkoutDay(
      type: 'gym',
      pill: '헬스',
      name: '헬스 · 하체 · 복근 · 어깨 · 유산소',
      ex: [
        '스쿼트',
        '레그 프레스',
        '레그 컬',
        '행잉 레그 레이즈',
        '사이드 레터럴 레이즈',
        '숄더 프레스',
      ],
    ),
    6: WorkoutDay(
      type: 'body',
      pill: '맨몸 C',
      name: '맨몸운동 C · 미는 힘 + 코어',
      log: ['pushup', 'plank'],
    ),
    0: WorkoutDay(
      type: 'body',
      pill: '맨몸 D',
      name: '맨몸운동 D · 가벼운 코어 (선택)',
      log: ['pushup', 'plank'],
    ),
  };

  /// 매일 고정 루틴
  static const daily = <DailyRoutine>[
    DailyRoutine('read', '독서', '독서 30~35페이지', '독서 탭에서 진도를 기록하십시오'),
    DailyRoutine('dev', '개발', '개발 — 최소 25분 또는 커밋 1회', '틈날 때마다'),
    DailyRoutine('toeic', '토익', '토익 공부', '평일 LC+단어 / 주말 RC 문법'),
  ];

  /// 오늘 탭 하단 메모 (요일별)
  static const notes = <int, String>{
    1: '주의 시작 — 헬스로 기분 좋게 출발하십시오.',
    2: '미는 힘의 날. 푸쉬업 폼에 집중하십시오.',
    3: '주 중반 — 가슴·이두. 정자세 우선.',
    4: '당기는 힘의 날. 풀업이 안 되면 네거티브부터.',
    5: '마지막 헬스 — 하체는 가장 큰 근육입니다.',
    6: '주말 맨몸운동. 가볍게라도 빈도를 지키십시오.',
    0: '휴식의 날. 한 주를 정리하십시오.',
  };
}

class BodyExercise {
  final String label;
  final String unit;
  const BodyExercise(this.label, this.unit);
}

class WorkoutDay {
  final String type; // 'gym' | 'body'
  final String pill;
  final String name;
  final List<String> ex; // 헬스 종목
  final List<String> log; // 맨몸 종목 key
  const WorkoutDay({
    required this.type,
    required this.pill,
    required this.name,
    this.ex = const [],
    this.log = const [],
  });
}

class DailyRoutine {
  final String id;
  final String pill;
  final String name;
  final String desc;
  const DailyRoutine(this.id, this.pill, this.name, this.desc);
}

/// 웹 버전 CSS :root 변수에 대응하는 색상 팔레트.
class AppColors {
  AppColors._();
  static const bg = Color(0xFF0D0F0E);
  static const panel = Color(0xFF16191A);
  static const panel2 = Color(0xFF1D2123);
  static const line = Color(0xFF2C3134);
  static const ink = Color(0xFFE8E6E0);
  static const inkDim = Color(0xFF9AA0A0);
  static const inkFaint = Color(0xFF646B6B);
  static const accent = Color(0xFFD8662F);
  static const accentSoft = Color(0xFFE8915F);
  static const gym = Color(0xFF5A8FC7);
  static const body = Color(0xFF7FAE6A);
  static const done = Color(0xFF6FB98F);
  static const study = Color(0xFFB98FD6);

  /// 루틴 타입(type)별 stripe/pill 색.
  static Color forType(String type) {
    switch (type) {
      case 'gym':
        return gym;
      case 'body':
        return body;
      case 'study':
        return study;
      case 'daily':
      default:
        return accent;
    }
  }
}
