// Zustand der Online-Seite und alle Aktionen darin. Die Ansichten lesen hier und rufen hier auf.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';

import '../../../data/services/device/device.dart' as device;
import '../../../data/services/storage/storage_base.dart';
import '../../../data/services/connection.dart';
import '../../../data/services/street_view/street_view_controller.dart';
import '../../../data/repositories/game_data.dart';
import '../../local/view_model/local_controller.dart';
import '../../../domain/models/models.dart';

const _sessionKey = 'werwolf.session';
const _nameKey = 'werwolf.name';
const _settingsOpenKey = 'arynta.settingsOpen';
const _languageKey = 'arynta.language';
const _toastDuration = Duration(seconds: 4);

/// Ja/Nein-Abfrage. Die Oberfläche setzt hier ihren Dialog ein.
typedef Confirm = Future<bool> Function(String question, String yesLabel);

typedef LinkFactory = GameLink Function(
  void Function(ServerMessage) onMessage,
  void Function(ConnectionStatus) onStatus,
  void Function() onOpen,
);

class Session {
  const Session(this.code, this.secret);
  final String code;
  final String secret;
}

class AppController extends ChangeNotifier {
  AppController({required this.storage, required LinkFactory createLink, String initialCode = ''}) {
    _link = createLink(handleMessage, _setStatus, _rejoin);
    if (storage.readJson(_sessionKey) case {'code': final String code, 'secret': final String secret}) {
      session = Session(code, secret);
    }
    if (storage.readJson(_nameKey) case final String name) nameInput.text = name;
    settingsOpen = storage.readJson(_settingsOpenKey) == true;
    _useLanguage(Language.parse(storage.read(_languageKey)));
    codeInput.text = initialCode.toUpperCase();
  }

  final Storage storage;
  late final GameLink _link;

  /// Bis die Oberfläche ihren Dialog einsetzt, wird nichts bestätigt.
  Confirm confirm = (_, _) async => false;

  ConnectionStatus status = ConnectionStatus.waking;

  /// Sprache der Oberfläche. Eigener Notifier, weil daran die ganze App hängt und nicht jede Änderung sie neu baut.
  final language = ValueNotifier(Language.de);
  Session? session;
  RoomView? room;
  bool settingsOpen = false;
  String? toast;
  bool _waitingForRejoin = false;

  /// Tabu: wann der laufende Zug endet (Uhr dieses Handys).
  DateTime? turnDeadline;

  /// Geo-Bingo: Spielende und Ende jeder Abstimmung (Claim-ID → Zeitpunkt), ebenfalls nach der Uhr dieses Handys.
  DateTime? geoBingoDeadline;
  Map<String, DateTime> voteDeadlines = const {};

  /// Geo-Bingo: der eigene Straßenbild-Viewer, aus dem ein Fund gemeldet wird.
  final streetView = StreetViewController();

  /// Gesetzt, solange man ohne Server mit einem Handy spielt.
  LocalController? local;

  /// Beitreten mit einem Code, den es nicht gibt: Feld rot. [codeRejections] zählt hoch, damit es jedes Mal wackelt.
  bool codeInvalid = false;
  int codeRejections = 0;

  final nameInput = TextEditingController();
  final codeInput = TextEditingController();

  /// Eigenes Impostor-Wort, das der Host gerade tippt, aber noch nicht übernommen hat.
  final customWordInput = TextEditingController();

  /// Nobody is Perfect: was im Antwortfeld steht, noch nicht abgeschickt.
  final answerInput = TextEditingController();

  /// Bekommt den Fokus, wenn der Name fehlt.
  final nameFocus = FocusNode();

  Timer? _toastTimer;
  bool _disposed = false;

  Future<void> start() => _link.start();

  void resume() => _link.resume();

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    _link.dispose();
    local?.dispose();
    nameInput.dispose();
    codeInput.dispose();
    customWordInput.dispose();
    answerInput.dispose();
    nameFocus.dispose();
    language.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Deutsch ↔ Englisch. Der Server bekommt es mit, damit Hinweise und Fehler passen.
  void toggleLanguage() {
    _useLanguage(language.value.other);
    storage.write(_languageKey, language.value.wire);
    _link.send(ClientMessage.setLanguage(language.value));
    _changed();
  }

  void _useLanguage(Language next) {
    language.value = next;
    appLanguage = next;
    device.setPageLanguage(next.wire);
  }

  void _setStatus(ConnectionStatus next) {
    status = next;
    _changed();
  }

  void _rejoin() {
    final current = session;
    if (current == null) return;
    _waitingForRejoin = true;
    _link.send(ClientMessage.rejoin(current.code, current.secret, language.value));
  }

  void handleMessage(ServerMessage msg) {
    switch (msg) {
      case Joined(:final code, :final secret):
        session = Session(code, secret);
        _waitingForRejoin = false;
        storage.writeJson(_sessionKey, {'code': code, 'secret': secret});
        device.showRoomInAddress(code);
      case StateMessage(:final state):
        // Ein eigenes Wort gilt nur für eine Runde, also beim Spielstart auch das Eingabefeld leeren
        if (room?.phase == Phase.lobby && state.phase != Phase.lobby) customWordInput.clear();
        // Neue Nobody-is-Perfect-Frage, neues leeres Antwortfeld
        if (state.phase != Phase.writing || state.round != room?.round) answerInput.clear();
        room = state;
        // Restzeit statt Endzeitpunkt vom Server, damit falsch gestellte Handy-Uhren nicht stören
        final tabu = state.tabu;
        turnDeadline = tabu != null && state.phase == Phase.turn
            ? DateTime.now().add(Duration(milliseconds: tabu.remainingMs))
            : null;
        final geoBingo = state.phase == Phase.geoBingo ? state.geoBingo : null;
        DateTime inMs(int ms) => DateTime.now().add(Duration(milliseconds: ms));
        geoBingoDeadline = geoBingo == null ? null : inMs(geoBingo.remainingMs);
        voteDeadlines = {for (final c in geoBingo?.claims ?? const <GeoBingoClaim>[]) c.id: inMs(c.remainingMs)};
      case LeftRoom():
        _forgetRoom();
      case Kicked():
        _forgetRoom();
        showToast(texts.toastKicked);
        return;
      case ErrorMessage(:final message, :final key):
        if (key == 'error.rooms.unknown' && !_waitingForRejoin) {
          codeInvalid = true;
          codeRejections++;
        }
        // Raum gibt es nach einem Server-Neustart nicht mehr
        if (_waitingForRejoin) _forgetRoom();
        showToast(message);
      case Pong():
        return;
    }
    _changed();
  }

  void _forgetRoom() {
    session = null;
    room = null;
    _waitingForRejoin = false;
    customWordInput.clear();
    storage.write(_sessionKey, null);
    device.showRoomInAddress(null);
  }

  void showToast(String text) {
    toast = text;
    _toastTimer?.cancel();
    _toastTimer = Timer(_toastDuration, () {
      toast = null;
      _changed();
    });
    _changed();
  }

  void _send(ClientMessage msg) {
    if (!_link.send(msg)) showToast(texts.toastOffline);
  }

  // ---- Startseite ------------------------------------------------------

  bool _requireName() {
    nameInput.text = nameInput.text.trim();
    if (nameInput.text.isEmpty) {
      showToast(texts.toastNameMissing);
      nameFocus.requestFocus();
      return false;
    }
    storage.writeJson(_nameKey, nameInput.text);
    return true;
  }

  void create() {
    if (_requireName()) _send(ClientMessage.create(nameInput.text, language.value));
  }

  void join() {
    if (!_requireName()) return;
    final code = codeInput.text.trim();
    if (code.isEmpty) {
      showToast(texts.toastCodeMissing);
      return;
    }
    _send(ClientMessage.join(code, nameInput.text, language.value));
  }

  void codeChanged() {
    if (!codeInvalid) return;
    codeInvalid = false;
    _changed();
  }

  /// Enter im Namensfeld: beitreten, wenn schon ein Code dasteht, sonst Raum erstellen.
  void submitName() {
    if (status != ConnectionStatus.online) return;
    codeInput.text.isEmpty ? create() : join();
  }

  void openLocal() {
    local = LocalController(
      storage: storage,
      toast: showToast,
      confirm: (question, yes) => confirm(question, yes),
      exit: closeLocal,
    )..addListener(_changed);
    _changed();
  }

  void closeLocal() {
    final old = local;
    local = null;
    _changed();
    old?.dispose();
  }

  // ---- Lobby -----------------------------------------------------------

  void setSettingsOpen(bool open) {
    settingsOpen = open;
    storage.writeJson(_settingsOpenKey, open);
    _changed();
  }

  void selectGame(GameType game) {
    if (game != room?.game) _send(ClientMessage.selectGame(game));
    _changed();
  }

  void changePlayerLimit(int step) {
    final current = room;
    if (current != null) _send(ClientMessage.setPlayerLimit(current.playerLimit.value + step));
  }

  void toggleReady() => _send(ClientMessage.setReady(!(room?.you.ready ?? false)));

  /// Schickt die Impostor-Einstellungen. Was nicht angegeben ist, bleibt wie es auf dem Server steht.
  void configureImpostor({bool? seesCategory, String? customWord}) {
    final current = room?.impostorSettings;
    if (current == null) return;
    _send(
      ClientMessage.configureImpostor(
        impostorSeesCategory: seesCategory ?? current.impostorSeesCategory,
        customWord: customWord ?? current.customWord ?? '',
      ),
    );
  }

  void saveWord() => configureImpostor(customWord: customWordInput.text);

  void clearWord() {
    customWordInput.clear();
    configureImpostor(customWord: '');
  }

  void setImpostorOptions({int? impostorCount, bool? randomStartPlayer}) {
    final current = room?.impostorSettings;
    if (current == null) return;
    _send(
      ClientMessage.setImpostorOptions(
        impostorCount: impostorCount ?? current.impostorCount,
        randomStartPlayer: randomStartPlayer ?? current.randomStartPlayer,
      ),
    );
  }

  void changeImpostorCount(int step) {
    final current = room?.impostorSettings;
    if (current != null) setImpostorOptions(impostorCount: current.impostorCount + step);
  }

  void toggleCategory(String name, bool selected) {
    final current = room?.impostorSettings;
    if (current == null) return;
    _send(
      ClientMessage.setImpostorCategories([
        for (final c in current.allCategories)
          if (c == name ? selected : current.selectedCategories.contains(c)) c,
      ]),
    );
  }

  void _configureWerwolf({int? Function()? werewolfCount, List<String>? roles, bool? hostIsGameMaster}) {
    final current = room?.werwolfSettings;
    if (current == null) return;
    _send(
      ClientMessage.configureWerwolf(
        werewolfCount: werewolfCount != null ? werewolfCount() : current.werewolfCount,
        roles: roles ?? current.selectedRoles,
        hostIsGameMaster: hostIsGameMaster ?? current.hostIsGameMaster,
      ),
    );
  }

  void changeWerewolfCount(int step) {
    final current = room?.werwolfSettings;
    if (current != null) _configureWerwolf(werewolfCount: () => current.effectiveWerewolfCount + step);
  }

  void autoWerewolves() => _configureWerwolf(werewolfCount: () => null);

  void setHostIsGameMaster(bool value) => _configureWerwolf(hostIsGameMaster: value);

  /// Schickt die Auswahl in der Reihenfolge der Rollenliste.
  void toggleRole(String id, bool selected) {
    final current = room?.werwolfSettings;
    if (current == null) return;
    _configureWerwolf(
      roles: [
        for (final role in gameData.specialRoles)
          if (role.id == id ? selected : current.selectedRoles.contains(role.id)) role.id,
      ],
    );
  }

  void configureTabu({int? turnSeconds, bool? autoTeams, int? teamCount, int? targetScore}) {
    final current = room?.tabuSettings;
    if (current == null) return;
    _send(
      ClientMessage.configureTabu(
        turnSeconds: turnSeconds ?? current.turnSeconds,
        autoTeams: autoTeams ?? current.autoTeams,
        teamCount: teamCount ?? current.teamCount,
        targetScore: targetScore ?? current.targetScore,
      ),
    );
  }

  void changeTurnSeconds(int step) {
    final current = room?.tabuSettings;
    if (current != null) configureTabu(turnSeconds: current.turnSeconds + step * Tabu.turnSecondsStep);
  }

  void changeTargetScore(int step) {
    final current = room?.tabuSettings;
    if (current != null) configureTabu(targetScore: current.targetScore + step * Tabu.targetScoreStep);
  }

  void changeTeamCount(int step) {
    final current = room?.tabuSettings;
    if (current != null) configureTabu(teamCount: current.teamCount + step);
  }

  void chooseTeam(int team) => _send(ClientMessage.chooseTeam(team));

  /// Host verschiebt jemanden ins nächste Team (nach dem letzten wieder ins erste).
  void moveToNextTeam(String playerId) {
    final settings = room?.tabuSettings;
    if (settings == null) return;
    final current = settings.teams.indexWhere((ids) => ids.contains(playerId));
    _send(ClientMessage.chooseTeam((current + 1) % settings.teamCount, targetId: playerId));
  }

  void changeQuestionCount(int step) {
    final current = room?.nobodyIsPerfectSettings;
    if (current != null) _send(ClientMessage.configureNobodyIsPerfect(current.questionCount + step));
  }

  void setBuzzerLockout(bool lockout) => _send(ClientMessage.configureBuzzer(lockout));

  /// In Schritten von 5 Minuten.
  void changeGeoBingoMinutes(int step) {
    final current = room?.geoBingoSettings;
    if (current != null) _send(ClientMessage.configureGeoBingo(current.minutes + step * 5));
  }

  Future<void> shareRoom() async {
    final code = room?.code;
    if (code == null) return;
    if (await device.shareRoom(code, texts.shareInvite(code)) == device.ShareResult.copied) showToast(texts.toastLinkCopied);
  }

  Future<void> leave() async {
    if (!await confirm(texts.confirmLeave, texts.confirmLeaveYes)) return;
    if (!_link.send(ClientMessage.leave())) {
      _forgetRoom();
      _changed();
    }
  }

  Future<void> kick(String playerId) async {
    final player = room?.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null) return;
    if (await confirm(texts.confirmKick(player.name), texts.confirmKickYes)) {
      _send(ClientMessage.kick(player.id));
    }
  }

  // ---- Im Spiel --------------------------------------------------------

  void startGame() => _send(ClientMessage.start());
  void nextPhase() => _send(ClientMessage.nextPhase());
  void startVoting() => _send(ClientMessage.startVoting());
  void vote(String targetId) => _send(ClientMessage.vote(targetId));
  void startTurn() => _send(ClientMessage.startTurn());
  void wordCorrect() => _send(ClientMessage.wordCorrect());
  void wordSkip() => _send(ClientMessage.wordSkip());
  void buzz() => _send(ClientMessage.buzz());

  void submitAnswer() {
    if (answerInput.text.trim().isEmpty) {
      showToast(texts.toastAnswerMissing);
      return;
    }
    _send(ClientMessage.submitAnswer(answerInput.text));
  }

  void guessAnswer(String choice) => _send(ClientMessage.guessAnswer(choice));
  void skipWaiting() => _send(ClientMessage.skipWaiting());
  void nextQuestion() => _send(ClientMessage.nextQuestion());
  void pressBuzzer() => _send(ClientMessage.pressBuzzer());
  void releaseBuzzer() => _send(ClientMessage.releaseBuzzer());

  /// Meldet das Feld mit genau der Ansicht, die man gerade im eigenen Straßenbild sieht.
  Future<void> claimGeoBingoField(int field) async {
    final spot = await streetView.currentSpot();
    if (spot == null) {
      showToast(texts.toastStreetViewLoading);
      return;
    }
    _send(ClientMessage.claimGeoBingoField(field, spot));
  }

  void voteGeoBingo(String claimId, bool accept) => _send(ClientMessage.voteGeoBingo(claimId, accept));
  void nextRound() => _send(ClientMessage.nextRound());

  Future<void> backToLobby() async {
    if (await confirm(texts.confirmBackToLobby, texts.confirmBackToLobbyYes)) {
      _send(ClientMessage.backToLobby());
    }
  }

  Future<void> forgetDevice() async {
    final inRoom = session != null;
    final question = inRoom ? texts.confirmForgetInRoom : texts.confirmForget;
    if (!await confirm(question, texts.confirmForgetYes)) return;

    if (inRoom) _link.send(ClientMessage.leave());
    _forgetRoom();
    forgetLocalSetup(storage);
    nameInput.clear();
    storage.write(_nameKey, null);
    storage.write(_languageKey, null);
    showToast(texts.toastForgotten);
  }
}
