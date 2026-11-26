import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'share_result.dart';

/// Schreibt den Raumcode in die Adresszeile, damit Neuladen wieder dorthin führt.
void showRoomInAddress(String? code) {
  final location = web.window.location;
  final query = code == null ? '' : '?raum=$code';
  // history.state gehört Flutter und muss erhalten bleiben
  web.window.history.replaceState(web.window.history.state, '', '${location.pathname}$query${location.hash}');
}

/// Damit Vorlesefunktionen die Seite in der richtigen Sprache sprechen.
void setPageLanguage(String code) => web.document.documentElement?.setAttribute('lang', code);

/// [text] ist die Einladung in der Sprache der Oberfläche.
Future<ShareResult> shareRoom(String code, String text) async {
  final location = web.window.location;
  final url = '${location.origin}${location.pathname}?raum=$code';
  try {
    if (web.window.navigator.has('share')) {
      await web.window.navigator
          .share(web.ShareData(title: 'Arynta', text: text, url: url))
          .toDart;
      return ShareResult.shared;
    }
    await Clipboard.setData(ClipboardData(text: url));
    return ShareResult.copied;
  } catch (_) {
    return ShareResult.cancelled; // Teilen abgebrochen, nichts zu tun
  }
}

/// true, wenn das E-Mail-Programm angestoßen wurde.
Future<bool> writeMail(String address) async {
  web.window.location.href = 'mailto:$address';
  return true;
}
