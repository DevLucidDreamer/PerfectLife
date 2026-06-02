import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'date_util.dart';
import 'models.dart';
import 'onboarding/routine_profile.dart';

/// 웹 버전의 Store + AppState + Stats + Schedule를 통합한 앱 상태.
/// localStorage('gatsaeng2') 대신 SharedPreferences에 JSON으로 저장한다.
class Store extends ChangeNotifier {
  static const _key = 'gatsaeng2';

  late SharedPreferences _prefs;
  AppData data = AppData();

  // ---- 화면 상태 (웹 AppState) ----
  int viewOffset = 0; // 0=오늘, -1=어제 (어제까지만 허용)
  DateTime statMonth = DateTime.now();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        data = AppData();
      }
    }
    notifyListeners();
  }

  Future<void> save() async {
    await _prefs.setString(_key, jsonEncode(data.toJson()));
    notifyListeners();
  }

  /// 특정 날짜의 체크 객체 (없으면 생성)
  DayRecord day(String k) => data.days.putIfAbsent(k, () => DayRecord());

  // ===================== AppState =====================
  DateTime viewDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: viewOffset));
  }

  bool get isToday => viewOffset == 0;

  void shiftViewDay(int delta) {
    final next = viewOffset + delta;
    if (next > 0 || next < -1) return; // 미래 불가, 그제 이전 불가
    viewOffset = next;
    notifyListeners();
  }

  void resetViewDay() {
    viewOffset = 0;
    notifyListeners();
  }

  void shiftMonth(int delta) {
    statMonth = DateTime(statMonth.year, statMonth.month + delta, 1);
    notifyListeners();
  }

  // ===================== Profile =====================
  /// 개인화 프로필 (없으면 Config 기반 기본 루틴 사용).
  RoutineProfile? get profile => data.profile;

  /// 온보딩 적용 여부.
  bool get usingProfile => data.profile?.onboarded == true;

  /// 백지 상태 + 프로필 없음 → 첫 실행 온보딩이 필요.
  bool get needsOnboarding => data.profile == null && data.isEmpty;

  ReadingPlan? get readingPlan => data.profile?.reading;

  void saveProfile(RoutineProfile p) {
    data.profile = p;
    save();
  }

  // ===================== 사용자 이름 =====================
  String get userName => data.userName;

  void setUserName(String name) {
    data.userName = name.trim();
    save();
  }

  // ===================== 유산소 =====================
  List<CardioLog> cardioOf(String k) =>
      data.cardioLogs.where((l) => l.date == k).toList();

  void addCardio(String k, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    data.cardioLogs.add(CardioLog(date: k, text: t));
    save();
  }

  void removeCardio(CardioLog log) {
    data.cardioLogs.remove(log);
    save();
  }

  /// 그 날 공유할 운동 기록(헬스/맨몸/유산소)이 하나라도 있는지.
  bool hasWorkoutData(String k) =>
      data.gymLogs.any((l) => l.date == k) ||
      data.bodyLogs.any((l) => l.date == k) ||
      data.cardioLogs.any((l) => l.date == k);

  /// 초기 설정 이후 특정 날짜의 헬스 세션에 종목을 추가한다.
  /// 분할이 설정된 요일이면 그 분할에, 아니면 공통 헬스 목록에 추가한다.
  /// 추가에 성공하면 true, 프로필/헬스가 없거나 이미 있으면 false.
  bool addGymExerciseForDate(DateTime d, String exercise) {
    final wp = data.profile?.workout;
    if (wp == null || !wp.hasGym) return false;
    final ex = exercise.trim();
    if (ex.isEmpty) return false;
    if (wp.splitDays.isNotEmpty) {
      final sd = wp.splitDays[wp.gymSplitIndexFor(d)];
      if (sd.exercises.contains(ex)) return false;
      sd.exercises.add(ex);
    } else {
      if (wp.gymExercises.contains(ex)) return false;
      wp.gymExercises.add(ex);
    }
    save();
    return true;
  }

  /// 맨몸 종목 키 → 라벨/단위. 표준 종목은 Config, 사용자 기타 종목은 프로필에서 해석.
  BodyExercise bodyMeta(String key) {
    final c = Config.bodyLog[key];
    if (c != null) return c;
    final custom = data.profile?.workout?.customBodyMeta[key];
    if (custom != null) return custom;
    return BodyExercise(key, '회');
  }

  // ===================== Schedule =====================
  /// 보고 있는 날짜의 할 일 목록.
  List<TaskItem> buildTasks() => buildTasksForDate(viewDate());

  /// 특정 날짜의 할 일 목록. 프로필이 있으면 개인화, 없으면 Config 기본 루틴.
  List<TaskItem> buildTasksForDate(DateTime d) {
    final p = data.profile;
    if (p != null && p.onboarded) return _profileTasks(p, d);
    return _defaultTasks(d);
  }

  List<TaskItem> _profileTasks(RoutineProfile p, DateTime d) {
    final list = <TaskItem>[];
    final wp = p.workout;
    if (wp != null) {
      // 같은 날 헬스+맨몸이면 세션이 둘 나온다.
      for (final wk in wp.sessionsFor(d)) {
        list.add(TaskItem(
          id: wk.type == 'gym' ? 'workout' : 'workoutBody',
          pill: wk.pill,
          type: wk.type,
          name: wk.name,
          workout: wk,
        ));
      }
    }
    if (p.reading != null) {
      list.add(TaskItem(
        id: 'read',
        pill: '독서',
        type: 'daily',
        name: p.reading!.taskName,
        desc: '독서 탭에서 진도를 기록하십시오',
      ));
    }
    // 공부: 주간 빈도에 따라 배정된 요일에만 표시한다.
    // (배정되지 않은 날은 항목 자체가 없으므로 연속을 끊지 않는다.)
    for (var i = 0; i < p.study.length; i++) {
      final s = p.study[i];
      if (!s.scheduledOn(d)) continue;
      list.add(TaskItem(
        id: 'study$i',
        pill: '공부',
        type: 'study',
        name: s.daysPerWeek >= 7 ? s.name : '${s.name} · ${s.freqLabel}',
      ));
    }
    // 취미: 매일 표시하되 optional — 체크하지 않아도 연속·진행률에 영향이 없다.
    for (var i = 0; i < p.hobby.length; i++) {
      list.add(TaskItem(
          id: 'hobby$i',
          pill: '취미',
          type: 'hobby',
          name: p.hobby[i],
          optional: true));
    }
    return list;
  }

  List<TaskItem> _defaultTasks(DateTime d) {
    final dow = d.weekday % 7; // Dart: Mon=1..Sun=7 → JS Sun=0..Sat=6
    final wk = Config.workout[dow]!;
    final list = <TaskItem>[
      TaskItem(
        id: 'workout',
        pill: wk.pill,
        type: wk.type,
        name: wk.name,
        workout: wk,
      ),
    ];
    for (final r in Config.daily) {
      list.add(TaskItem(id: r.id, pill: r.pill, type: 'daily', name: r.name, desc: r.desc));
    }
    if (dow == 0) {
      list.add(TaskItem(
        id: 'sqld',
        pill: 'SQLD',
        type: 'study',
        name: 'SQLD 주 1회 학습',
        desc: 'TODO 탭에서 세부 계획을 관리하십시오',
      ));
    }
    return list;
  }

  // ===================== Stats =====================
  /// 하루 완료 여부 (연속 달성 판정용). 그 날 생성되는 할 일을 모두 체크하면 완료.
  /// 할 일이 없는 날(예: 운동만 선택한 사용자의 휴식일)은 연속을 끊지 않는다.
  bool isDayComplete(DateTime d) {
    // 취미 등 optional 항목은 연속 달성 판정에서 제외한다(강제성 없음).
    final tasks =
        buildTasksForDate(d).where((t) => !t.optional).toList();
    if (tasks.isEmpty) return true;
    final rec = data.days[DateUtil.dkey(d)];
    if (rec == null) return false;
    return tasks.every((t) => rec.checks[t.id] == true);
  }

  int streak() {
    int s = 0;
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    for (int i = 0; i < 400; i++) {
      if (isDayComplete(d)) {
        s++;
      } else if (i != 0) {
        break;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  /// 특정 날짜의 헬스 총 볼륨
  double gymVolumeOf(String k) {
    double vol = 0;
    for (final l in data.gymLogs.where((l) => l.date == k)) {
      vol += l.volume;
    }
    return vol;
  }

  MonthlyStats monthly(String mk) {
    final bAgg = <String, double>{};
    for (final l in data.bodyLogs.where((l) => l.date.startsWith(mk))) {
      bAgg[l.ex] = (bAgg[l.ex] ?? 0) + l.value;
    }
    final gAgg = <String, double>{};
    for (final l in data.gymLogs.where((l) => l.date.startsWith(mk))) {
      gAgg[l.ex] = (gAgg[l.ex] ?? 0) + l.volume;
    }
    final workoutDays = <String>{
      ...data.bodyLogs.where((l) => l.date.startsWith(mk)).map((l) => l.date),
      ...data.gymLogs.where((l) => l.date.startsWith(mk)).map((l) => l.date),
    }.length;
    final monthPages = data.readLogs
        .where((l) => l.date.startsWith(mk))
        .fold<int>(0, (s, l) => s + l.pages);
    final finishedBooks =
        data.books.where((b) => b.done && b.finMonth == mk).toList();
    final totalVol = gAgg.values.fold<double>(0, (a, b) => a + b);
    return MonthlyStats(
      bAgg: bAgg,
      gAgg: gAgg,
      workoutDays: workoutDays,
      monthPages: monthPages,
      finishedBooks: finishedBooks,
      totalVol: totalVol,
    );
  }

  // ===================== Routine 액션 =====================
  void toggleCheck(String taskId) {
    final d = day(DateUtil.dkey(viewDate()));
    d.checks[taskId] = !(d.checks[taskId] ?? false);
    save();
  }

  void completeAll() {
    final d = day(DateUtil.dkey(viewDate()));
    for (final t in buildTasks()) {
      d.checks[t.id] = true;
    }
    save();
  }

  void resetToday() {
    day(DateUtil.dkey(viewDate())).checks = {};
    save();
  }

  // ===================== Workout 저장 =====================
  void saveBody(String k, WorkoutDay wk, Map<String, double> values) {
    data.bodyLogs.removeWhere((l) => l.date == k && wk.log.contains(l.ex));
    values.forEach((ex, v) {
      if (v > 0) data.bodyLogs.add(BodyLog(date: k, ex: ex, value: v));
    });
    save();
  }

  void saveGym(String k, WorkoutDay wk, Map<String, List<GymSet>> blocks) {
    data.gymLogs.removeWhere((l) => l.date == k && wk.ex.contains(l.ex));
    blocks.forEach((ex, sets) {
      final valid = sets.where((s) => s.w > 0 && s.r > 0).toList();
      if (valid.isNotEmpty) data.gymLogs.add(GymLog(date: k, ex: ex, sets: valid));
    });
    save();
  }

  // ===================== Reading =====================
  /// 책 진도 갱신. 반환: (완독 여부, 메시지)
  ReadingResult updatePage(int id, int newPage) {
    final b = data.books.firstWhere((x) => x.id == id, orElse: () => Book(id: -1, title: '', total: 0, current: 0));
    if (b.id == -1) return ReadingResult(false, '');
    newPage = newPage.clamp(0, b.total);
    final diff = newPage - b.current;
    if (diff > 0) {
      data.readLogs.add(ReadLog(date: DateUtil.dkey(), bookId: id, pages: diff));
    }
    b.current = newPage;
    String msg;
    bool finished = false;
    if (newPage >= b.total && b.total > 0) {
      b.done = true;
      b.finMonth = DateUtil.mkey();
      b.finDate = DateUtil.dkey();
      msg = "'${b.title}' 완독을 축하합니다";
      finished = true;
    } else {
      msg = '독서 진도 기록됨';
    }
    if (diff > 0) {
      day(DateUtil.dkey()).checks['read'] = true;
    }
    save();
    return ReadingResult(finished, msg);
  }

  bool addBook(String title, int total, int start) {
    if (title.isEmpty || total <= 0) return false;
    data.books.add(Book(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      total: total,
      current: start.clamp(0, total),
    ));
    save();
    return true;
  }

  void deleteBook(int id) {
    data.books.removeWhere((x) => x.id == id);
    data.readLogs.removeWhere((x) => x.bookId == id);
    save();
  }

  // ===================== Todo =====================
  bool addTodo(String text, String tag) {
    if (text.isEmpty) return false;
    data.todos.add(TodoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      text: text,
      tag: tag,
      created: DateUtil.dkey(),
    ));
    save();
    return true;
  }

  void toggleTodo(int id) {
    for (final t in data.todos) {
      if (t.id == id) {
        t.done = !t.done;
        break;
      }
    }
    save();
  }

  void removeTodo(int id) {
    data.todos.removeWhere((x) => x.id == id);
    save();
  }
}

/// 웹 buildTasks가 만들던 동적 항목.
class TaskItem {
  final String id;
  final String pill;
  final String type;
  final String name;
  final String? desc;
  final WorkoutDay? workout;

  /// true면 연속 달성·진행률 계산에서 제외(취미 등 강제성 없는 항목).
  final bool optional;
  TaskItem({
    required this.id,
    required this.pill,
    required this.type,
    required this.name,
    this.desc,
    this.workout,
    this.optional = false,
  });
}

class MonthlyStats {
  final Map<String, double> bAgg;
  final Map<String, double> gAgg;
  final int workoutDays;
  final int monthPages;
  final List<Book> finishedBooks;
  final double totalVol;
  MonthlyStats({
    required this.bAgg,
    required this.gAgg,
    required this.workoutDays,
    required this.monthPages,
    required this.finishedBooks,
    required this.totalVol,
  });
}

class ReadingResult {
  final bool finished;
  final String message;
  ReadingResult(this.finished, this.message);
}
