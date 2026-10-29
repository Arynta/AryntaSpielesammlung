package de.kruschinski.werwolf.game;

/** Einstellungen für Nobody is Perfect, die der Host in der Lobby wählt. */
public record NobodyIsPerfectOptions(int questionCount) {

    public static final int MIN_QUESTIONS = 3;
    public static final int MAX_QUESTIONS = 20;
    public static final int MAX_ANSWER_LENGTH = 100;

    public static final NobodyIsPerfectOptions DEFAULT = new NobodyIsPerfectOptions(8);

    public NobodyIsPerfectOptions {
        if (questionCount < MIN_QUESTIONS || questionCount > MAX_QUESTIONS) {
            throw new GameException("Es kann " + MIN_QUESTIONS + " bis " + MAX_QUESTIONS + " Fragen geben.");
        }
    }
}
