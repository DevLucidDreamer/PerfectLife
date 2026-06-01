import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// 웹(PWA): 파일 시스템 없이 메모리 바이트를 Web Share API로 바로 공유.
/// 브라우저가 파일 공유를 지원하지 않으면 share_plus가 다운로드로 대체한다.
Future<void> shareImageBytes(
    Uint8List bytes, String fileName, String text) async {
  final file = XFile.fromData(bytes, name: fileName, mimeType: 'image/png');
  await Share.shareXFiles([file], text: text, fileNameOverrides: [fileName]);
}
