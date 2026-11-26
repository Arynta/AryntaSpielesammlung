package de.kruschinski.werwolf.game;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.random.RandomGenerator;

/** Motive und Startorte für Geo-Bingo aus {@code games/geo-bingo.json}. */
public final class GeoBingoData {

    /** Mittelpunkt, um den die App das erste Straßenbild sucht. */
    public record Place(String name, double lat, double lng) {
    }

    private record DataFile(List<String> motifs, List<Place> places) {
    }

    private static final DataFile DATA = GameData.read("games/geo-bingo.json", DataFile.class);

    private GeoBingoData() {
    }

    static List<String> pickMotifs(int count, RandomGenerator random) {
        List<String> motifs = new ArrayList<>(DATA.motifs());
        Shuffle.inPlace(motifs, random);
        return List.copyOf(motifs.subList(0, count));
    }

    /** Nimmt einen Ort, der in diesem Raum noch nicht dran war. Sind alle durch, geht es von vorn los. */
    static Place pickPlace(Collection<String> used, RandomGenerator random) {
        List<Place> fresh = DATA.places().stream().filter(p -> !used.contains(p.name())).toList();
        List<Place> pool = fresh.isEmpty() ? DATA.places() : fresh;
        return pool.get(random.nextInt(pool.size()));
    }
}
