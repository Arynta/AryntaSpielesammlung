// Zugriff auf die Texte aus app_de.arb und app_en.arb (daraus erzeugt Flutter app_localizations.dart).
import 'package:flutter/widgets.dart';

import '../domain/models/language.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Sprache der Oberfläche. Setzt nur der AppController.
Language appLanguage = Language.de;

/// Texte in der aktuellen Sprache, auch dort, wo es keinen BuildContext gibt (Controller, Regeln).
AppLocalizations get texts => lookupAppLocalizations(Locale(appLanguage.wire));

/// Tabu-Teams im lokalen Modus, online kommen die Namen vom Server.
List<String> get tabuTeamNames => [texts.teamRed, texts.teamBlue, texts.teamGreen, texts.teamYellow];
