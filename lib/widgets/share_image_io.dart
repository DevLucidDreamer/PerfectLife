import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 네이티브(Android/iOS): 임시 디렉터리에 PNG를 쓴 뒤 파일 경로로 공유.
Future<void> shareImageBytes(
    Uint8List bytes, String fileName, String text) async {
  final dir = await getTemporaryDirectory();
  final f = await File('${dir.path}/$fileName').writeAsBytes(bytes);
  await Share.shareXFiles([XFile(f.path)], text: text);
}
