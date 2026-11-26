// Wörter und Rollen kommen aus denselben Dateien wie im Backend, damit es nur eine Liste gibt
// (tool/sync_assets.dart kopiert sie nach assets/game/).
import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

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
  WordCategory.fromJson(Json j) : name = j['name'] as String, words = List<String>.from(j['words'] as List);
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

  List<String> get categoryNames => [for (final c in categories) c.name];

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
  static Future<GameData> load([Future<String> Function(String file)? read]) async {
    final load = read ?? (String file) => rootBundle.loadString('assets/game/$file');
    Future<Json> json(String file) async => jsonDecode(await load(file)) as Json;
    return GameData(
      roleFile: await json('werwolf-roles.json'),
      wordFile: await json('impostor-words.json'),
      cardFile: await json('tabu-cards.json'),
      questionFile: await json('nobody-is-perfect-questions.json'),
    );
  }
}

/// Wird beim Start einmal gefüllt (main.dart bzw. Tests).
late GameData gameData;

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
};
const maxImpostorsOverall = maxPlayers ~/ 2 - 1;

/// Länge eines eigenen Impostor-Worts.
const maxCustomWordLength = 30;

// Gleiche Werte wie im Backend (TabuOptions, TabuGame)
abstract final class Tabu {
  static const teamNames = ['Team Rot', 'Team Blau', 'Team Grün', 'Team Gelb'];
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
