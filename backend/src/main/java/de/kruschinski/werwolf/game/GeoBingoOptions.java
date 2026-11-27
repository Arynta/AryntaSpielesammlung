package de.kruschinski.werwolf.game;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Einstellungen für Geo-Bingo, die der Host in der Lobby wählt. {@code size}: Felder pro Reihe.
 * {@code motifs}: eigene Begriffe, die immer auf die Karte kommen; den Rest füllt die Standardliste auf.
 */
public record GeoBingoOptions(int minutes, int size, List<String> motifs) {

    public static final int MIN_MINUTES = 5;
    public static final int MAX_MINUTES = 30;
    public static final int MIN_SIZE = 3;
    /** Die Standardliste hat 40 Begriffe, für 6×6 reicht sie also immer zum Auffüllen. */
    public static final int MAX_SIZE = 6;
    public static final int MAX_MOTIFS = MAX_SIZE * MAX_SIZE;
    public static final int MAX_MOTIF_LENGTH = Room.MAX_WORD_LENGTH;

    public static final GeoBingoOptions DEFAULT = new GeoBingoOptions(10, MIN_SIZE, List.of());

    public GeoBingoOptions {
        if (minutes < MIN_MINUTES || minutes > MAX_MINUTES) {
            throw new GameException("error.geoBingo.minutes", MIN_MINUTES, MAX_MINUTES);
        }
        if (size < MIN_SIZE || size > MAX_SIZE) {
            throw new GameException("error.geoBingo.size", MIN_SIZE, MAX_SIZE);
        }
        motifs = cleanMotifs(motifs);
    }

    GeoBingoOptions withTimeAndSize(int minutes, int size) {
        return new GeoBingoOptions(minutes, size, motifs);
    }

    GeoBingoOptions withMotifs(List<String> motifs) {
        return new GeoBingoOptions(minutes, size, motifs);
    }

    /** Leere Einträge fallen weg. Groß- und Kleinschreibung zählt beim Vergleich nicht. */
    private static List<String> cleanMotifs(List<String> raw) {
        List<String> cleaned = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (String entry : raw) {
            String motif = Room.normalizeText(entry);
            if (motif.isEmpty()) {
                continue;
            }
            if (motif.length() > MAX_MOTIF_LENGTH) {
                throw new GameException("error.geoBingo.motifTooLong", MAX_MOTIF_LENGTH);
            }
            if (!seen.add(motif.toLowerCase(Locale.ROOT))) {
                throw new GameException("error.geoBingo.motifTwice", motif);
            }
            cleaned.add(motif);
        }
        if (cleaned.size() > MAX_MOTIFS) {
            throw new GameException("error.geoBingo.tooManyMotifs", MAX_MOTIFS);
        }
        return List.copyOf(cleaned);
    }
}
