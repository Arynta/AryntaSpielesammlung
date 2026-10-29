package de.kruschinski.werwolf.game;

import java.util.List;

/**
 * Die Wortkarten für Tabu. Sie stehen in {@code games/tabu-cards.json},
 * damit der lokale Modus im Frontend dieselben Karten nutzt.
 */
public final class TabuCards {

    /** Der gesuchte Begriff und die Wörter, die beim Erklären verboten sind. */
    public record Card(String word, List<String> forbidden) {
    }

    private record CardFile(List<Card> cards) {
    }

    private static final List<Card> CARDS = GameData.read("games/tabu-cards.json", CardFile.class).cards();

    private TabuCards() {
    }

    public static List<Card> all() {
        return CARDS;
    }
}
