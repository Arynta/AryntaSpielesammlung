package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.List;
import java.util.Map;

/**
 * Die Wortkarten für Tabu. Sie stehen in {@code games/tabu-cards*.json},
 * damit der lokale Modus im Frontend dieselben Karten nutzt.
 */
public final class TabuCards {

    /** Der gesuchte Begriff und die Wörter, die beim Erklären verboten sind. */
    public record Card(String word, List<String> forbidden) {
    }

    private record CardFile(List<Card> cards) {
    }

    private static final Map<Language, CardFile> FILES = GameData.perLanguage("tabu-cards", CardFile.class);

    private TabuCards() {
    }

    public static List<Card> all(Language language) {
        return FILES.get(language).cards();
    }
}
