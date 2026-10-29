package de.kruschinski.werwolf.game;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.random.RandomGenerator;

/**
 * Die eingebaute Wortliste für Impostor. Die Wörter stehen in {@code games/impostor-words.json},
 * damit der lokale Modus im Frontend dieselbe Liste nutzt.
 */
public final class ImpostorWords {

    /** Ein geheimes Wort. {@code category} ist {@code null}, wenn der Host es selbst eingegeben hat. */
    public record SecretWord(String word, String category) {
    }

    private record Category(String name, List<String> words) {
    }

    private record WordFile(List<Category> categories) {
    }

    private static final List<Category> CATEGORIES =
            GameData.read("games/impostor-words.json", WordFile.class).categories();

    private ImpostorWords() {
    }

    /** Alle Kategorien in fester Reihenfolge, so wie sie der Host zur Auswahl sieht. */
    public static List<String> categoryNames() {
        return CATEGORIES.stream().map(Category::name).toList();
    }

    /**
     * Ein zufälliges Wort aus den gewählten Kategorien, das noch nicht in {@code alreadyUsed} steht.
     * Sind dort alle verbraucht, geht es in diesen Kategorien von vorne los.
     */
    public static SecretWord pick(RandomGenerator random, Collection<String> alreadyUsed, Collection<String> categories) {
        List<SecretWord> inCategories = allWords().stream()
                .filter(w -> categories.contains(w.category()))
                .toList();
        if (inCategories.isEmpty()) {
            throw new GameException("Bitte wähle mindestens eine Kategorie.");
        }
        List<SecretWord> unused = inCategories.stream()
                .filter(w -> !alreadyUsed.contains(w.word()))
                .toList();
        List<SecretWord> candidates = unused.isEmpty() ? inCategories : unused;
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
