// Für Android und iOS (später). Ohne Zusatzpakete: Teilen und E-Mail kopieren in die Zwischenablage.
import 'package:flutter/services.dart';

import 'share_result.dart';

/// Adresse der Webseite für Einladungslinks: --dart-define=WEB_URL=https://…
const _webUrl = String.fromEnvironment('WEB_URL');

void showRoomInAddress(String? code) {}

Future<ShareResult> shareRoom(String code) async {
  final text = _webUrl.isEmpty ? code : '$_webUrl?raum=$code';
  await Clipboard.setData(ClipboardData(text: text));
  return ShareResult.copied;
}

/// false: Die Adresse liegt nur in der Zwischenablage.
Future<bool> writeMail(String address) async {
  await Clipboard.setData(ClipboardData(text: address));
  return false;
}
