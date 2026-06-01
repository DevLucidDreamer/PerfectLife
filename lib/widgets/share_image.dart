// 캡처한 PNG 바이트를 플랫폼에 맞게 공유한다.
//
// - 네이티브: 임시 파일로 저장 후 공유 (share_image_io.dart)
// - 웹/PWA: 메모리에서 Web Share API로 공유 (share_image_web.dart)
//
// 기본 구현은 웹용이며, dart:io가 있는 네이티브에서는 io 구현으로 대체된다.
export 'share_image_web.dart'
    if (dart.library.io) 'share_image_io.dart';
