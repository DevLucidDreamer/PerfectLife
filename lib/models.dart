// 웹 버전 localStorage 스키마를 그대로 옮긴 데이터 모델.
// JSON 구조는 기존 'gatsaeng2' 키와 호환되도록 유지한다.

import 'onboarding/routine_profile.dart';

/// 헬스 세트 한 줄: 무게(w) × 횟수(r)
class GymSet {
  double w;
  double r;
  GymSet(this.w, this.r);

  double get volume => w * r;

  Map<String, dynamic> toJson() => {'w': w, 'r': r};
  factory GymSet.fromJson(Map<String, dynamic> j) =>
      GymSet((j['w'] as num).toDouble(), (j['r'] as num).toDouble());
}

/// 헬스 기록: {date, ex, sets:[{w,r}]}
class GymLog {
  String date;
  String ex;
  List<GymSet> sets;
  GymLog({required this.date, required this.ex, required this.sets});

  double get volume => sets.fold(0, (a, s) => a + s.volume);

  Map<String, dynamic> toJson() =>
      {'date': date, 'ex': ex, 'sets': sets.map((s) => s.toJson()).toList()};
  factory GymLog.fromJson(Map<String, dynamic> j) => GymLog(
        date: j['date'] as String,
        ex: j['ex'] as String,
        sets: (j['sets'] as List)
            .map((e) => GymSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 유산소 기록: {date, text} — 자유 형식 (예: "런닝 3km - 27'")
class CardioLog {
  String date;
  String text;
  CardioLog({required this.date, required this.text});

  Map<String, dynamic> toJson() => {'date': date, 'text': text};
  factory CardioLog.fromJson(Map<String, dynamic> j) => CardioLog(
        date: j['date'] as String,
        text: j['text'] as String? ?? '',
      );
}

/// 맨몸운동 기록: {date, ex, value}
class BodyLog {
  String date;
  String ex;
  double value;
  BodyLog({required this.date, required this.ex, required this.value});

  Map<String, dynamic> toJson() => {'date': date, 'ex': ex, 'value': value};
  factory BodyLog.fromJson(Map<String, dynamic> j) => BodyLog(
        date: j['date'] as String,
        ex: j['ex'] as String,
        value: (j['value'] as num).toDouble(),
      );
}

/// 책: {id,title,total,current,done,finMonth,finDate}
class Book {
  int id;
  String title;
  int total;
  int current;
  bool done;
  String? finMonth;
  String? finDate;
  Book({
    required this.id,
    required this.title,
    required this.total,
    required this.current,
    this.done = false,
    this.finMonth,
    this.finDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'total': total,
        'current': current,
        'done': done,
        'finMonth': finMonth,
        'finDate': finDate,
      };
  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        total: (j['total'] as num).toInt(),
        current: (j['current'] as num).toInt(),
        done: j['done'] as bool? ?? false,
        finMonth: j['finMonth'] as String?,
        finDate: j['finDate'] as String?,
      );
}

/// 독서 진도 로그: {date, bookId, pages}
class ReadLog {
  String date;
  int bookId;
  int pages;
  ReadLog({required this.date, required this.bookId, required this.pages});

  Map<String, dynamic> toJson() =>
      {'date': date, 'bookId': bookId, 'pages': pages};
  factory ReadLog.fromJson(Map<String, dynamic> j) => ReadLog(
        date: j['date'] as String,
        bookId: (j['bookId'] as num).toInt(),
        pages: (j['pages'] as num).toInt(),
      );
}

/// 시험 TODO: {id,text,tag,done,created}
class TodoItem {
  int id;
  String text;
  String tag;
  bool done;
  String created;
  TodoItem({
    required this.id,
    required this.text,
    required this.tag,
    this.done = false,
    required this.created,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'tag': tag, 'done': done, 'created': created};
  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        id: (j['id'] as num).toInt(),
        text: j['text'] as String,
        tag: j['tag'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        created: j['created'] as String? ?? '',
      );
}

/// 날짜별 체크 상태: {checks:{taskId:bool}}
class DayRecord {
  Map<String, bool> checks;
  DayRecord({Map<String, bool>? checks}) : checks = checks ?? {};

  Map<String, dynamic> toJson() => {'checks': checks};
  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(
        checks: (j['checks'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as bool),
            ) ??
            {},
      );
}

/// 앱 전체 데이터. 웹의 Store.data와 동일한 최상위 구조.
class AppData {
  Map<String, DayRecord> days;
  List<BodyLog> bodyLogs;
  List<GymLog> gymLogs;
  List<CardioLog> cardioLogs;
  List<Book> books;
  List<ReadLog> readLogs;
  List<TodoItem> todos;

  /// 사용자 이름 (운동 기록 텍스트 공유 등에 사용).
  String userName;

  /// 온보딩으로 생성된 개인화 루틴 프로필. null이면 Config 기반 기본 루틴 사용.
  RoutineProfile? profile;

  AppData({
    Map<String, DayRecord>? days,
    List<BodyLog>? bodyLogs,
    List<GymLog>? gymLogs,
    List<CardioLog>? cardioLogs,
    List<Book>? books,
    List<ReadLog>? readLogs,
    List<TodoItem>? todos,
    this.userName = '',
    this.profile,
  })  : days = days ?? {},
        bodyLogs = bodyLogs ?? [],
        gymLogs = gymLogs ?? [],
        cardioLogs = cardioLogs ?? [],
        books = books ?? [],
        readLogs = readLogs ?? [],
        todos = todos ?? [];

  /// 기록이 전혀 없는 백지 상태 (온보딩 표시 판정용).
  bool get isEmpty =>
      days.isEmpty &&
      bodyLogs.isEmpty &&
      gymLogs.isEmpty &&
      cardioLogs.isEmpty &&
      books.isEmpty &&
      readLogs.isEmpty &&
      todos.isEmpty;

  Map<String, dynamic> toJson() => {
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'bodyLogs': bodyLogs.map((e) => e.toJson()).toList(),
        'gymLogs': gymLogs.map((e) => e.toJson()).toList(),
        'cardioLogs': cardioLogs.map((e) => e.toJson()).toList(),
        'books': books.map((e) => e.toJson()).toList(),
        'readLogs': readLogs.map((e) => e.toJson()).toList(),
        'todos': todos.map((e) => e.toJson()).toList(),
        'userName': userName,
        'profile': profile?.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        days: (j['days'] as Map?)?.map(
              (k, v) => MapEntry(
                k as String,
                DayRecord.fromJson(v as Map<String, dynamic>),
              ),
            ) ??
            {},
        bodyLogs: (j['bodyLogs'] as List?)
                ?.map((e) => BodyLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        gymLogs: (j['gymLogs'] as List?)
                ?.map((e) => GymLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        cardioLogs: (j['cardioLogs'] as List?)
                ?.map((e) => CardioLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        books: (j['books'] as List?)
                ?.map((e) => Book.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        readLogs: (j['readLogs'] as List?)
                ?.map((e) => ReadLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        todos: (j['todos'] as List?)
                ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        userName: j['userName'] as String? ?? '',
        profile: j['profile'] == null
            ? null
            : RoutineProfile.fromJson(j['profile'] as Map<String, dynamic>),
      );
}
