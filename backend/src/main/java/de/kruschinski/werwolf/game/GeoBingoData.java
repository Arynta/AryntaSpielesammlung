package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;

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

    static List<String> pickMotifs(Language language, int count, RandomGenerator random) {
        List<String> motifs = new ArrayList<>(motifs(language));
        Shuffle.inPlace(motifs, random);
        return List.copyOf(motifs.subList(0, count));
    }

    /** Nimmt einen Ort, der in diesem Raum noch nicht dran war. Sind alle durch, geht es von vorn los. */
    static Place pickPlace(Language language, Collection<String> used, RandomGenerator random) {
        List<Place> places = places(language);
        List<Place> fresh = places.stream().filter(p -> !used.contains(p.name())).toList();
        List<Place> pool = fresh.isEmpty() ? places : fresh;
        return pool.get(random.nextInt(pool.size()));
    }
}
