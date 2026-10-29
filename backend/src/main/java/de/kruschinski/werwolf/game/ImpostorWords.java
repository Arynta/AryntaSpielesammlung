package de.kruschinski.werwolf.game;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.random.RandomGenerator;

/** Die eingebaute Wortliste für Impostor. Neue Wörter oder Kategorien einfach unten ergänzen. */
public final class ImpostorWords {

    /** Ein geheimes Wort. {@code category} ist {@code null}, wenn der Host es selbst eingegeben hat. */
    public record SecretWord(String word, String category) {
    }

    private record Category(String name, List<String> words) {
    }

    private static final List<Category> CATEGORIES = List.of(
            new Category("Tiere", List.of(
                    "Elefant", "Pinguin", "Giraffe", "Krokodil", "Eichhörnchen", "Delfin", "Kuh", "Fledermaus",
                    "Schnecke", "Papagei", "Känguru", "Igel", "Hai", "Biene", "Eule")),
            new Category("Essen und Trinken", List.of(
                    "Pizza", "Spaghetti", "Döner", "Pfannkuchen", "Sushi", "Brezel", "Popcorn", "Erdbeere",
                    "Schokolade", "Kaffee", "Bratwurst", "Käse", "Banane", "Eis", "Suppe")),
            new Category("Orte", List.of(
                    "Strand", "Krankenhaus", "Flughafen", "Schule", "Kino", "Bahnhof", "Zoo", "Bibliothek",
                    "Supermarkt", "Tankstelle", "Schwimmbad", "Kirche", "Bäckerei", "Freizeitpark", "Campingplatz")),
            new Category("Berufe", List.of(
                    "Feuerwehrmann", "Arzt", "Lehrer", "Pilot", "Koch", "Polizist", "Bauer", "Zahnarzt",
                    "Friseur", "Astronaut", "Bäcker", "Tierarzt", "Postbote", "Clown", "Detektiv")),
            new Category("Im Haushalt", List.of(
                    "Kühlschrank", "Staubsauger", "Toaster", "Bügeleisen", "Waschmaschine", "Zahnbürste",
                    "Kopfkissen", "Spiegel", "Regenschirm", "Wecker", "Kerze", "Fernbedienung", "Besen",
                    "Gabel", "Badewanne")),
            new Category("Sport", List.of(
                    "Fußball", "Tennis", "Schwimmen", "Skifahren", "Boxen", "Basketball", "Golf", "Reiten",
                    "Klettern", "Bowling", "Volleyball", "Tischtennis", "Surfen", "Marathon", "Schach")),
            new Category("Fahrzeuge", List.of(
                    "Fahrrad", "Hubschrauber", "U-Boot", "Traktor", "Feuerwehrauto", "Kreuzfahrtschiff",
                    "Straßenbahn", "Rakete", "Skateboard", "Motorrad", "Heißluftballon", "Krankenwagen",
                    "Taxi", "Kanu", "Bagger")),
            new Category("Natur", List.of(
                    "Vulkan", "Regenbogen", "Wasserfall", "Wüste", "Gewitter", "Gletscher", "Insel", "Höhle",
                    "Sonnenuntergang", "Wald", "Mond", "Schneemann", "Kaktus", "Pilz", "Tornado")),
            new Category("Freizeit", List.of(
                    "Geburtstag", "Hochzeit", "Zelten", "Karaoke", "Achterbahn", "Picknick", "Silvester",
                    "Konzert", "Flohmarkt", "Grillen", "Brettspiel", "Weihnachten", "Zirkus", "Angeln",
                    "Halloween")),
            new Category("Kleidung", List.of(
                    "Gummistiefel", "Krawatte", "Badehose", "Schlafanzug", "Sonnenbrille", "Handschuhe",
                    "Hut", "Bademantel", "Rucksack", "Turnschuhe", "Schal", "Brautkleid", "Mütze",
                    "Hosenträger", "Pullover"))
    );

    private ImpostorWords() {
    }

    /** Ein zufälliges Wort, das noch nicht in {@code alreadyUsed} steht. Sind alle verbraucht, geht es von vorne los. */
    public static SecretWord pick(RandomGenerator random, Collection<String> alreadyUsed) {
        List<SecretWord> candidates = allWords().stream()
                .filter(w -> !alreadyUsed.contains(w.word()))
                .toList();
        if (candidates.isEmpty()) {
            candidates = allWords();
        }
        return candidates.get(random.nextInt(candidates.size()));
    }

    static List<SecretWord> allWords() {
        List<SecretWord> all = new ArrayList<>();
        for (Category category : CATEGORIES) {
            category.words().forEach(word -> all.add(new SecretWord(word, category.name())));
        }
        return all;
    }
}
