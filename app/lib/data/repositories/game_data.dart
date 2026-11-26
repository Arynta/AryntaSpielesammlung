// Wörter und Rollen kommen aus denselben Dateien wie im Backend, damit es nur eine Liste gibt
// (tool/sync_assets.dart kopiert sie nach assets/game/). Jede Datei gibt es auf Deutsch und mit -en auf Englisch.
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/models.dart';
import '../../l10n/l10n.dart';

class RoleData {
  RoleData.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      team = j['team'] as String,
      description = j['description'] as String,
      wolfPack = j['wolfPack'] as bool? ?? false,
      seesWolfPack = j['seesWolfPack'] as bool? ?? false;
  final String id;
  final String name;
  final String team;
  final String description;

  /// Wacht mit den Wölfen auf: kennt das Rudel und wird von ihm erkannt.
  final bool wolfPack;

  /// Kennt das Rudel, wird aber nicht erkannt (Günstling).
  final bool seesWolfPack;
}

class WordCategory {
  WordCategory.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      words = List<String>.from(j['words'] as List);

  /// Gleich in allen Sprachen.
  final String id;
  final String name;
  final List<String> words;
}

class NobodyIsPerfectQuestion {
  NobodyIsPerfectQuestion.fromJson(Json j) : question = j['question'] as String, answer = j['answer'] as String;
  final String question;
  final String answer;
}

class GameData {
  GameData({required Json roleFile, required Json wordFile, required Json cardFile, required Json questionFile})
    : roles = [for (final r in roleFile['roles'] as List) RoleData.fromJson(r as Json)],
      teamNames = {for (final t in roleFile['teams'] as List) (t as Json)['id'] as String: t['name'] as String},
      categories = [for (final c in wordFile['categories'] as List) WordCategory.fromJson(c as Json)],
      tabuCards = [for (final c in cardFile['cards'] as List) TabuCard.fromJson(c as Json)],
      questions = [for (final q in questionFile['questions'] as List) NobodyIsPerfectQuestion.fromJson(q as Json)];

  final List<RoleData> roles;

  /// Team-ID → Name, in der Reihenfolge der Datei.
  final Map<String, String> teamNames;
  final List<WordCategory> categories;
  final List<TabuCard> tabuCards;
  final List<NobodyIsPerfectQuestion> questions;

  List<String> get categoryIds => [for (final c in categories) c.id];

  String categoryName(String id) => categories.firstWhere((c) => c.id == id).name;

  /// Rollen zum Ankreuzen. Dorfbewohner füllen auf, Werwölfe werden gezählt.
  List<RoleData> get specialRoles => [
    for (final r in roles)
      if (r.id != villager && r.id != werewolf) r,
  ];

  RoleData roleById(String id) =>
      roles.firstWhere((r) => r.id == id, orElse: () => throw StateError('Unbekannte Rolle: $id'));

  RoleCard cardFor(RoleData role) => RoleCard(
    id: role.id,
    name: role.name,
    team: role.team,
    teamName: teamNames[role.team]!,
    description: role.description,
  );

  /// [read] liefert den Inhalt einer Datei aus assets/game/.
  static Future<GameData> load(Language language, [Future<String> Function(String file)? read]) async {
    final load = read ?? (String file) => rootBundle.loadString('assets/game/$file');
    final suffix = language == Language.de ? '' : '-${language.wire}';
    Future<Json> json(String name) async => jsonDecode(await load('$name$suffix.json')) as Json;
    return GameData(
      roleFile: await json('werwolf-roles'),
      wordFile: await json('impostor-words'),
      cardFile: await json('tabu-cards'),
      questionFile: await json('nobody-is-perfect-questions'),
    );
  }

  static Future<Map<Language, GameData>> loadAll([Future<String> Function(String file)? read]) async => {
    for (final language in Language.values) language: await load(language, read),
  };
}

/// Spieldaten je Sprache. Wird beim Start einmal gefüllt (main.dart bzw. Tests).
late Map<Language, GameData> gameDataByLanguage;

/// Daten in der Sprache der Oberfläche. Danach richten sich Rollen, Wörter und Karten im lokalen Modus.
GameData get gameData => gameDataByLanguage[appLanguage]!;

const villager = 'DORFBEWOHNER';
const werewolf = 'WERWOLF';
const seer = 'SEHERIN';

/// Mit Dieb kommen zwei Karten mehr ins Spiel, aus denen er tauschen darf.
const thief = 'DIEB';
const thiefExtraCards = 2;

// Gleiche Werte wie im Backend (GameType, Room, ImpostorOptions)
const maxPlayers = 20;
const minPlayers = {
  GameType.werwolf: 4,
  GameType.impostor: 3,
  GameType.tabu: 4,
  GameType.nobodyIsPerfect: 3,
  GameType.buzzer: 2,
  GameType.geoBingo: 2,
};
const maxImpostorsOverall = maxPlayers ~/ 2 - 1;

/// Länge eines eigenen Impostor-Worts.
const maxCustomWordLength = 30;

// Gleiche Werte wie im Backend (TabuOptions, TabuGame)
abstract final class Tabu {
  static const minTurnSeconds = 30;
  static const maxTurnSeconds = 180;
  static const turnSecondsStep = 15;
  static const minTeams = 2;
  static const maxTeams = 4;
  static const minTargetScore = 10;
  static const maxTargetScore = 100;
  static const targetScoreStep = 5;
  static const minTeamSize = 2;
}

// Gleiche Werte wie im Backend (NobodyIsPerfectOptions)
abstract final class NobodyIsPerfectRules {
  static const minQuestions = 3;
  static const maxQuestions = 20;
  static const defaultQuestions = 8;
  static const maxAnswerLength = 100;
}

/// Kartenbilder für Rollen. Hat eine Rolle ein Bild, zeigt die Karte das Bild statt des Rollennamens.
const roleImages = {werewolf: 'assets/game/Werwolf_werwolf1.png'};

/// Bilder für die Spielereihe auf der Startseite. Spiele ohne Bild bekommen einen Farbverlauf mit Namen.
const gamePosters = {GameType.impostor: 'assets/game/impostor-karte.jpg'};

/// Große Bilder hinter dem Kopf von Lobby und Lokal-Einrichtung. Spiele ohne Bild bekommen einen Farbschein.
const gameHeroes = {GameType.impostor: 'assets/game/impostor-gross.jpg'};

/// Spieleabend am Tisch, hinter dem Kopf der Startseite.
const homeImage = 'assets/game/spieleabend.jpg';
