package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;

/**
 * Die eingebaute Wortliste für Impostor. Die Wörter stehen in {@code games/impostor-words*.json},
 * damit der lokale Modus im Frontend dieselbe Liste nutzt. Kategorien heißen in jeder Sprache anders,
 * deshalb wählt der Host sie über ihre {@code id}.
 */
public final class ImpostorWords {

    /** Ein geheimes Wort. {@code category} ist {@code null}, wenn der Host es selbst eingegeben hat. */
    public record SecretWord(String word, String category) {
    }

    private record Category(String id, String name, List<String> words) {
    }

    private record WordFile(List<Category> categories) {
    }

    private static final Map<Language, WordFile> FILES = GameData.perLanguage("impostor-words", WordFile.class);

    private ImpostorWords() {
    }

    /** Alle Kategorien in fester Reihenfolge, so wie sie der Host zur Auswahl sieht. */
    public static List<String> categoryIds() {
        return categories(Language.DE).stream().map(Category::id).toList();
    }

    /** Die Namen zu {@link #categoryIds()} in derselben Reihenfolge. */
    public static List<String> categoryNames(Language language) {
        return categories(language).stream().map(Category::name).toList();
    }

    /**
     * Ein zufälliges Wort aus den gewählten Kategorien, das noch nicht in {@code alreadyUsed} steht.
     * Sind dort alle verbraucht, geht es in diesen Kategorien von vorne los.
     */
    public static SecretWord pick(Language language, RandomGenerator random, Collection<String> alreadyUsed,
                                  Collection<String> categoryIds) {
        List<SecretWord> inCategories = allWords(language, categoryIds);
        if (inCategories.isEmpty()) {
            throw new GameException("error.impostor.noCategory");
        }
        List<SecretWord> unused = inCategories.stream()
                .filter(w -> !alreadyUsed.contains(w.word()))
                .toList();
        List<SecretWord> candidates = unused.isEmpty() ? inCategories : unused;
        return candidates.get(random.nextInt(candidates.size()));
    }

    static List<SecretWord> allWords(Language language) {
        return allWords(language, categoryIds());
    }

    private static List<SecretWord> allWords(Language language, Collection<String> categoryIds) {
        List<SecretWord> all = new ArrayList<>();
        for (Category category : categories(language)) {
            if (categoryIds.contains(category.id())) {
                category.words().forEach(word -> all.add(new SecretWord(word, category.name())));
            }
        }
        return all;
    }

    private static List<Category> categories(Language language) {
        return FILES.get(language).categories();
    }
}
