# 오늘부터 갓생 — 루틴 트래커 (Flutter)

웹(HTML/JS) 단일 파일로 만들었던 루틴 트래커를 **Flutter 네이티브 앱**으로 재작성한 프로젝트입니다. Android · iOS 모두 지원합니다.

## 기능
- **오늘 탭** — 요일별 루틴 체크, 날짜 네비게이션(오늘/어제), 운동 기록(헬스 세트별 무게×횟수 · 맨몸운동 수치), 진행률 링, 요일별 메모 + SQLD D-day
- **독서 탭** — 책 추가/삭제, 페이지 진도 슬라이더 + 기록, 완독 처리
- **시험 TODO 탭** — 할 일 추가/완료/삭제
- **월간 기록 탭** — 운동한 날, 헬스 총 볼륨/종목별 볼륨, 맨몸운동 누적, 독서 페이지/완독 권수
- **이미지 공유** — 9:16 스토리 카드를 캡처해 공유(인스타 스토리 등)
- **연속 달성(streak)** 계산

## 구조
```
lib/
  main.dart            앱 진입점 · 테마 · Provider 주입
  config.dart          운동 스케줄/루틴/색상 등 상수 (웹 Config 대응)
  models.dart          데이터 모델 + JSON 직렬화 (localStorage 스키마 호환)
  date_util.dart       날짜 키 유틸 (웹 DateUtil 대응)
  fonts.dart           Google Fonts 래퍼 + 숫자 콤마 포맷
  store.dart           ChangeNotifier 상태/로직 (웹 Store/AppState/Stats/Schedule 통합)
  screens/
    home_screen.dart   헤더 · 탭바 · 푸터 · IndexedStack
    today_tab.dart     오늘 탭
    reading_tab.dart   독서 탭
    todo_tab.dart      시험 TODO 탭
    stats_tab.dart     월간 기록 탭
  widgets/
    common.dart        진행률 링 · 섹션 타이틀 · 토스트 · 확인 다이얼로그
    workout_logger.dart 운동 기록 입력
    share_card.dart    공유 카드 렌더링 + 이미지 캡처/공유
legacy/
  index.html           원본 웹 버전 (참고용 보존)
```

## 웹 → Flutter 매핑
| 웹 | Flutter |
|---|---|
| `localStorage` | `shared_preferences` |
| 전역 객체(Store/AppState/Render) | `provider` + `ChangeNotifier` |
| Google Fonts CDN | `google_fonts` 패키지 |
| `<canvas>` 공유 이미지 | `RepaintBoundary` 캡처 + `share_plus` |

> 데이터 저장 키는 기존과 동일한 `gatsaeng2`(JSON)를 사용합니다.

## 실행
```bash
flutter pub get
flutter run                 # 연결된 기기/에뮬레이터에서 실행
flutter build apk           # Android 릴리스 APK
flutter build ios           # iOS (macOS + Xcode 필요)
```

> iOS 빌드·배포는 macOS + Xcode 환경이 필요합니다(현재 Windows에서 개발 중).
> `google_fonts`는 첫 실행 시 글꼴을 내려받습니다. 오프라인 보장이 필요하면 글꼴 파일을 `assets`로 번들하도록 전환할 수 있습니다.
