import 'dart:js_interop';

// index.html 의 window.pwaInstall.* 와 연결.
@JS('pwaInstall.isStandalone')
external bool _isStandalone();

@JS('pwaInstall.canInstall')
external bool _canInstall();

@JS('pwaInstall.isIos')
external bool _isIos();

@JS('pwaInstall.promptInstall')
external JSPromise<JSString> _promptInstall();

/// PWA로 설치되어 독립 실행(홈 화면 앱) 중인지.
bool pwaIsStandalone() => _isStandalone();

/// beforeinstallprompt 가 잡혀 있어 즉시 설치 프롬프트를 띄울 수 있는지.
bool pwaCanInstall() => _canInstall();

/// iOS/iPadOS Safari 인지 (이 경우 자동 설치 프롬프트가 없어 수동 안내 필요).
bool pwaIsIos() => _isIos();

/// 설치 프롬프트 실행. 'accepted' | 'dismissed' | 'unavailable' 반환.
Future<String> pwaPromptInstall() async {
  final res = await _promptInstall().toDart;
  return res.toDart;
}
