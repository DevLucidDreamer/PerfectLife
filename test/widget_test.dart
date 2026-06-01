// 갓생 트래커 기본 스모크 테스트 + 핵심 로직 단위 테스트.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perfect_life/date_util.dart';
import 'package:perfect_life/main.dart';
import 'package:perfect_life/models.dart';
import 'package:perfect_life/onboarding/routine_profile.dart';
import 'package:perfect_life/store.dart';
import 'package:perfect_life/widgets/workout_share.dart';

void main() {
  testWidgets('첫 실행(백지)에는 온보딩이 표시된다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const GatsaengApp()),
    );
    await tester.pump();

    expect(find.text('갓생을 위한 루틴!'), findsOneWidget);
    expect(find.text('운동'), findsWidgets);
  });

  testWidgets('온보딩 완료 후에는 홈 헤더가 렌더링된다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();
    // 프로필이 확정되면 첫 실행 온보딩을 건너뛰고 홈을 보여준다.
    store.saveProfile(RoutineProfile(
      onboarded: true,
      reading: ReadingPlan(pagesPerDay: 20),
      study: const ['토익 단어 30개'],
    ));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const GatsaengApp()),
    );
    await tester.pump();

    expect(find.textContaining('갓생'), findsWidgets);
    expect(find.text('오늘'), findsWidgets);
  });

  test('streak: 오늘이 미완료면 0', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();
    expect(store.streak(), 0);
  });

  test('addBook/updatePage: 완독 처리', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();
    store.addBook('테스트 책', 100, 0);
    final id = store.data.books.first.id;
    final res = store.updatePage(id, 100);
    expect(res.finished, true);
    expect(store.data.books.first.done, true);
  });

  test('buildSplitDays: 3분할 시퀀스 생성', () {
    final days = SplitTemplates.buildSplitDays(3);
    expect(days.length, 3);
    expect(days[0].label, '가슴 · 삼두');
    expect(days[1].label, '등 · 이두');
    expect(days[0].exercises, isNotEmpty);
  });

  test('suggestionsFor: 분할 부위에 맞는 종목만 추천한다', () {
    final s = SplitTemplates.suggestionsFor(label: '가슴 · 삼두', current: const []);
    // 가슴/삼두 종목은 포함, 다른 부위(하체)는 제외.
    expect(s, contains('벤치프레스'));
    expect(s, contains('케이블 푸쉬다운'));
    expect(s, isNot(contains('스쿼트')));
    // 라벨이 부위가 아니어도 현재 종목에서 부위를 유추한다.
    final s2 =
        SplitTemplates.suggestionsFor(label: '내 루틴', current: const ['스쿼트']);
    expect(s2, contains('레그 프레스'));
    expect(s2, isNot(contains('벤치프레스')));
    // 부위를 못 찾으면 전체 풀.
    final s3 = SplitTemplates.suggestionsFor(label: '전신', current: const []);
    expect(s3, SplitTemplates.allGymExercises);
  });

  test('assignGymBody: 주6회 헬스3 격일은 월수금/화목토', () {
    final weekdays = RoutineTemplates.weekdaysFor(6); // [1,2,3,4,5,6]
    final (gym, body) = SplitTemplates.assignGymBody(
        weekdays: weekdays, gymCount: 3, sameDay: false);
    expect(gym, [1, 3, 5]);
    expect(body, [2, 4, 6]);
  });

  WorkoutPlan gymPlan(int days, int splitCount, {String? start}) {
    final weekdays = RoutineTemplates.weekdaysFor(days)..sort();
    return WorkoutPlan(
      types: const ['gym'],
      daysPerWeek: days,
      weekdays: weekdays,
      gymCount: days,
      gymWeekdays: weekdays,
      gymExercises: const [],
      splitDays: SplitTemplates.buildSplitDays(splitCount),
      bodyKeys: const [],
      customExercises: const [],
      startDate: start,
    );
  }

  test('sessionsFor: 분할이 있으면 헬스 세션을 반환한다', () {
    final wp = gymPlan(5, 5, start: '2026-06-07'); // 일요일 기준
    // 월요일(2026-06-08): 첫 운동일 → 5분할 1번째 '가슴'.
    final mon = wp.sessionsFor(DateTime(2026, 6, 8));
    expect(mon.length, 1);
    expect(mon.first.name, contains('가슴'));
    // 일요일은 휴식.
    expect(wp.sessionsFor(DateTime(2026, 6, 7)), isEmpty);
  });

  test('분할 연속 순환: 주3회+5분할은 다음 주로 이어진다', () {
    final wp = gymPlan(3, 5, start: '2026-06-07'); // 운동일 월·수·금
    // 1주차 월·수·금 → 분할 0,1,2
    expect(wp.gymSplitIndexFor(DateTime(2026, 6, 8)), 0); // 월
    expect(wp.gymSplitIndexFor(DateTime(2026, 6, 10)), 1); // 수
    expect(wp.gymSplitIndexFor(DateTime(2026, 6, 12)), 2); // 금
    // 2주차 월·수 → 분할 3,4 (이어짐), 그 다음 금은 다시 0
    expect(wp.gymSplitIndexFor(DateTime(2026, 6, 15)), 3); // 월
    expect(wp.gymSplitIndexFor(DateTime(2026, 6, 17)), 4); // 수
    expect(wp.gymSplitIndexFor(DateTime(2026, 6, 19)), 0); // 금 → 한 바퀴
  });

  test('WorkoutPlan: 분할/요일 JSON 라운드트립', () {
    final wp = gymPlan(5, 5);
    final back = WorkoutPlan.fromJson(wp.toJson());
    expect(back.splitDays.length, wp.splitDays.length);
    expect(back.splitDays[0].label, wp.splitDays[0].label);
    expect(back.gymWeekdays, wp.gymWeekdays);
    expect(back.gymCount, wp.gymCount);
  });

  test('workoutShareText: 날짜·이름·종목 형식으로 작성된다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();
    store.setUserName('이재원');
    final k = DateUtil.dkey(store.viewDate());
    store.data.gymLogs.add(GymLog(date: k, ex: '벤치프레스', sets: [
      GymSet(40, 10),
      GymSet(40, 10),
      GymSet(40, 10),
    ]));
    store.addCardio(k, "런닝 3km - 27'");
    final text = workoutShareText(store);
    final vd = store.viewDate();
    expect(text, contains('${vd.month}/${vd.day}'));
    expect(text, contains('이재원'));
    expect(text, contains('벤치프레스 40 - 10 - 3')); // 균일 세트는 무게-횟수-세트
    expect(text, contains("런닝 3km - 27'"));
  });

  test('workoutShareText: 같은 세트는 묶고 다른 세트는 나열한다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();
    final k = DateUtil.dkey(store.viewDate());
    // 30×20 두 번 → 묶임
    store.data.gymLogs
        .add(GymLog(date: k, ex: '벤치', sets: [GymSet(30, 20), GymSet(30, 20)]));
    // 60×10 두 번 + 50×12 한 번 → "60 - 10 - 2, 50 - 12 - 1"
    store.data.gymLogs.add(GymLog(
        date: k,
        ex: '스쿼트',
        sets: [GymSet(60, 10), GymSet(60, 10), GymSet(50, 12)]));
    final text = workoutShareText(store);
    expect(text, contains('벤치 30 - 20 - 2'));
    expect(text, contains('스쿼트 60 - 10 - 2, 50 - 12 - 1'));
  });

  test('addGymExerciseForDate: 그 날 분할에 종목을 추가한다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.init();
    final wp = gymPlan(3, 5, start: '2026-06-07');
    store.saveProfile(RoutineProfile(onboarded: true, workout: wp));
    final d = DateTime(2026, 6, 8); // 월, 분할 인덱스 0
    final idx = wp.gymSplitIndexFor(d);
    final added = store.addGymExerciseForDate(d, '풀오버');
    expect(added, true);
    expect(store.data.profile!.workout!.splitDays[idx].exercises,
        contains('풀오버'));
    expect(store.addGymExerciseForDate(d, '풀오버'), false); // 중복
  });
}
