package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.random.RandomGenerator;
import java.util.stream.Collectors;

/** Motive und Startorte für Geo-Bingo aus {@code games/geo-bingo*.json}. */
public final class GeoBingoData {

    /** Mittelpunkt, um den die App das erste Straßenbild sucht. */
    public record Place(String name, double lat, double lng) {
    }

    private record DataFile(List<String> motifs, List<Place> places) {
    }

    private static final Map<Language, DataFile> FILES = GameData.perLanguage("geo-bingo", DataFile.class);

    private GeoBingoData() {
    }

    static List<String> motifs(Language language) {
        return FILES.get(language).motifs();
    }

    static List<Place> places(Language language) {
        return FILES.get(language).places();
    }

    /**
     * {@code count} Motive in zufälliger Reihenfolge: zuerst die eigenen ({@code own}), den Rest aus der
     * Standardliste ohne Begriffe, die schon drauf sind. Gibt es mehr eigene als Felder, entscheidet der Zufall.
     */
    static List<String> pickMotifs(Language language, List<String> own, int count, RandomGenerator random) {
        List<String> shuffledOwn = new ArrayList<>(own);
        Shuffle.inPlace(shuffledOwn, random);
        List<String> board = new ArrayList<>(shuffledOwn.subList(0, Math.min(count, shuffledOwn.size())));
        Set<String> taken = board.stream().map(m -> m.toLowerCase(Locale.ROOT)).collect(Collectors.toSet());
        List<String> standard = new ArrayList<>(motifs(language));
        Shuffle.inPlace(standard, random);
        standard.stream()
                .filter(m -> !taken.contains(m.toLowerCase(Locale.ROOT)))
                .limit(count - board.size())
                .forEach(board::add);
        Shuffle.inPlace(board, random);
        return List.copyOf(board);
    }

    /** Nimmt einen Ort, der in diesem Raum noch nicht dran war. Sind alle durch, geht es von vorn los. */
    static Place pickPlace(Language language, Collection<String> used, RandomGenerator random) {
        List<Place> places = places(language);
        List<Place> fresh = places.stream().filter(p -> !used.contains(p.name())).toList();
        List<Place> pool = fresh.isEmpty() ? places : fresh;
        return pool.get(random.nextInt(pool.size()));
    }
}
