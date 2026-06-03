/// 네이티브(Android/iOS 앱) 빌드용 no-op 구현.
/// 네이티브 앱은 이미 설치된 상태이므로 standalone 으로 간주한다.
bool pwaIsStandalone() => true;
bool pwaCanInstall() => false;
bool pwaIsIos() => false;
Future<String> pwaPromptInstall() async => 'unavailable';
