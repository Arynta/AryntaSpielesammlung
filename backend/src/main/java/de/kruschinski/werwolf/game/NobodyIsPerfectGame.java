package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.NobodyIsPerfectQuestions.Question;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;

/**
 * Nobody is Perfect: Zu einer kuriosen Frage denkt sich jeder eine glaubwürdige, aber falsche Antwort aus.
 * Dann stehen alle erfundenen Antworten und die echte gemischt zur Wahl, und jeder tippt auf die echte.
 * Richtig getippt gibt einen Punkt, und jeder, der auf die eigene Erfindung hereinfällt, auch.
 * Nicht threadsicher, {@link Room} synchronisiert.
 */
public final class NobodyIsPerfectGame implements Game {

    /** Eine Antwort zur Auswahl. {@code authorId} ist {@code null} bei der echten Antwort. */
    record Choice(String id, String text, String authorId) {
    }

    private final List<Player> participants;
    private final List<Question> questions;
    private final RandomGenerator random;
    private final Map<String, Integer> scores = new HashMap<>();
    /** Spieler-ID → erfundene Antwort zur aktuellen Frage. */
    private final Map<String, String> answers = new LinkedHashMap<>();
    /** Spieler-ID → ID der Antwort, auf die er tippt. */
    private final Map<String, String> guesses = new LinkedHashMap<>();
    /** Punkte, die es für die gerade aufgelöste Frage gab. */
    private final Map<String, Integer> gained = new HashMap<>();
    private List<Choice> choices = List.of();
    private int index;
    private Phase phase = Phase.WRITING;

    NobodyIsPerfectGame(List<Player> participants, List<Question> questions, RandomGenerator random) {
        if (questions.isEmpty()) {
            throw new GameException("Es gibt keine Fragen.");
        }
        this.participants = List.copyOf(participants);
        this.questions = List.copyOf(questions);
        this.random = random;
    }

    @Override
    public GameType type() {
        return GameType.NOBODY_IS_PERFECT;
    }

    @Override
    public Phase phase() {
        return phase;
    }

    /** Die Nummer der aktuellen Frage, ab 1. */
    @Override
    public int round() {
        return index + 1;
    }

    @Override
    public boolean betweenRounds() {
        return phase == Phase.RESULT;
    }

    public Question question() {
        return questions.get(index);
    }

    public int score(String playerId) {
        return scores.getOrDefault(playerId, 0);
    }

    List<Choice> choices() {
        return choices;
    }

    /** Antwort abgeben oder ändern, solange noch nicht alle fertig sind. */
    void submitAnswer(String playerId, String rawAnswer) {
        requirePhase(Phase.WRITING, "Gerade werden keine Antworten geschrieben.");
        requireParticipant(playerId);
        String answer = Room.normalizeText(rawAnswer);
        if (answer.isEmpty()) {
            throw new GameException("Bitte schreib eine Antwort.");
        }
        if (answer.length() > NobodyIsPerfectOptions.MAX_ANSWER_LENGTH) {
            throw new GameException("Die Antwort darf höchstens " + NobodyIsPerfectOptions.MAX_ANSWER_LENGTH + " Zeichen lang sein.");
        }
        answers.put(playerId, answer);
        closeStageIfComplete();
    }

    /** Tipp abgeben oder ändern. Auf die eigene Erfindung darf man nicht tippen. */
    void guess(String playerId, String choiceId) {
        requirePhase(Phase.GUESSING, "Gerade wird nicht getippt.");
        requireParticipant(playerId);
        Choice choice = choices.stream()
                .filter(c -> c.id().equals(choiceId))
                .findFirst()
                .orElseThrow(() -> new GameException("Diese Antwort gibt es nicht."));
        if (playerId.equals(choice.authorId())) {
            throw new GameException("Auf deine eigene Antwort kannst du nicht tippen.");
        }
        guesses.put(playerId, choiceId);
        closeStageIfComplete();
    }

    /** Geht weiter, sobald alle verbundenen Mitspieler fertig sind. Auch aufrufen, wenn jemand offline geht. */
    void closeStageIfComplete() {
        if (phase == Phase.WRITING && !answers.isEmpty() && allConnectedIn(answers)) {
            startGuessing();
        } else if (phase == Phase.GUESSING && !guesses.isEmpty() && allConnectedIn(guesses)) {
            reveal();
        }
    }

    /** Die Spielleitung wartet nicht länger auf die, die noch nicht fertig sind. */
    void skipWaiting() {
        if (phase == Phase.WRITING) {
            if (answers.isEmpty()) {
                throw new GameException("Noch hat niemand eine Antwort abgegeben.");
            }
            startGuessing();
        } else if (phase == Phase.GUESSING) {
            reveal();
        } else {
            throw new GameException("Gerade wird auf niemanden gewartet.");
        }
    }

    void nextQuestion() {
        requirePhase(Phase.REVEAL, "Die Frage ist noch nicht aufgelöst.");
        index++;
        answers.clear();
        guesses.clear();
        gained.clear();
        choices = List.of();
        phase = Phase.WRITING;
    }

    private void startGuessing() {
        List<Choice> mixed = new ArrayList<>();
        answers.forEach((playerId, answer) -> mixed.add(new Choice(null, answer, playerId)));
        mixed.add(new Choice(null, question().answer(), null));
        Shuffle.inPlace(mixed, random);
        List<Choice> lettered = new ArrayList<>();
        for (int i = 0; i < mixed.size(); i++) {
            Choice c = mixed.get(i);
            lettered.add(new Choice(String.valueOf((char) ('A' + i)), c.text(), c.authorId()));
        }
        choices = List.copyOf(lettered);
        phase = Phase.GUESSING;
    }

    /** Richtig getippt: +1. Jeder, der auf die eigene Erfindung hereinfällt: +1 für den Erfinder. */
    private void reveal() {
        guesses.forEach((guesserId, choiceId) -> {
            String authorId = choiceById(choiceId).authorId();
            gained.merge(authorId == null ? guesserId : authorId, 1, Integer::sum);
        });
        gained.forEach((playerId, points) -> scores.merge(playerId, points, Integer::sum));
        phase = index == questions.size() - 1 ? Phase.RESULT : Phase.REVEAL;
    }

    RoomView.NobodyIsPerfectView viewFor(String playerId) {
        boolean revealed = phase == Phase.REVEAL || phase == Phase.RESULT;
        List<RoomView.NobodyIsPerfectChoice> choiceViews = choices.stream()
                .map(c -> new RoomView.NobodyIsPerfectChoice(c.id(), c.text()))
                .toList();
        String yourChoiceId = choices.stream()
                .filter(c -> playerId.equals(c.authorId()))
                .map(Choice::id)
                .findFirst()
                .orElse(null);
        List<RoomView.NobodyIsPerfectReveal> reveal = revealed
                ? choices.stream().map(c -> new RoomView.NobodyIsPerfectReveal(
                        c.id(), c.text(), c.authorId() == null, c.authorId(), guessersOf(c.id()))).toList()
                : List.of();
        List<RoomView.NobodyIsPerfectScore> scoreViews = participants.stream()
                .map(p -> new RoomView.NobodyIsPerfectScore(p.id(), score(p.id()), gained.getOrDefault(p.id(), 0)))
                .toList();

        return new RoomView.NobodyIsPerfectView(
                index + 1,
                questions.size(),
                question().question(),
                revealed ? question().answer() : null,
                participants.stream().map(Player::id).toList(),
                List.copyOf(answers.keySet()),
                answers.get(playerId),
                phase == Phase.WRITING ? List.of() : choiceViews,
                yourChoiceId,
                List.copyOf(guesses.keySet()),
                guesses.get(playerId),
                reveal,
                scoreViews);
    }

    private List<String> guessersOf(String choiceId) {
        return guesses.entrySet().stream()
                .filter(e -> e.getValue().equals(choiceId))
                .map(Map.Entry::getKey)
                .toList();
    }

    private Choice choiceById(String choiceId) {
        return choices.stream().filter(c -> c.id().equals(choiceId)).findFirst().orElseThrow();
    }

    private boolean allConnectedIn(Map<String, String> done) {
        return participants.stream().filter(Player::connected).allMatch(p -> done.containsKey(p.id()));
    }

    private void requirePhase(Phase expected, String message) {
        if (phase != expected) {
            throw new GameException(message);
        }
    }

    private void requireParticipant(String playerId) {
        if (participants.stream().noneMatch(p -> p.id().equals(playerId))) {
            throw new GameException("Du spielst in dieser Runde nicht mit.");
        }
    }
}
