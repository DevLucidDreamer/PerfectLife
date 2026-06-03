/// PWA 설치 상태 조회·설치 트리거.
///
/// 웹에서는 [pwa_install_web.dart]가 `window.pwaInstall`(index.html) 헬퍼를
/// js_interop으로 호출하고, 네이티브(AAB) 빌드에서는 [pwa_install_stub.dart]가
/// "이미 앱"으로 동작해 설치 팝업이 뜨지 않게 한다.
library;

export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';
