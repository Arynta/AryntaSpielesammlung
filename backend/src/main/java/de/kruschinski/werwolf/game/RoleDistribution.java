package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Text;

import java.util.ArrayList;
import java.util.List;
import java.util.random.RandomGenerator;

/** Legt fest, welche Rollen bei wie vielen Spielern im Spiel sind, und teilt sie aus. */
public final class RoleDistribution {

    /** Karten der Spieler in derselben Reihenfolge wie die Spieler. {@code leftover} gibt es nur mit Dieb. */
    public record Deal(List<Role> perPlayer, List<Role> leftover) {
    }

    private RoleDistribution() {
    }

    /** Ein Werwolf pro angefangene vier Spieler (4–7 → 1, 8–11 → 2, ...). */
    public static int autoWerewolves(int playerCount) {
        return Math.max(1, playerCount / 4);
    }

    /** {@code chosenCount} ist {@code null}, wenn die Anzahl automatisch sein soll. */
    public static int werewolves(int playerCount, Integer chosenCount) {
        return chosenCount == null ? autoWerewolves(playerCount) : chosenCount;
    }

    /** Warum mit dieser Auswahl nicht verteilt werden kann, oder {@code null}, wenn alles passt. */
    public static Text problem(int playerCount, Integer chosenCount, List<String> specialRoles) {
        int minPlayers = GameType.WERWOLF.minPlayers();
        if (playerCount < minPlayers) {
            return Text.of("hint.werwolf.minPlayers", minPlayers);
        }
        int cards = werewolves(playerCount, chosenCount) + specialRoles.size();
        if (cards > playerCount) {
            return Text.of("hint.werwolf.tooManyRoles", cards, playerCount);
        }
        return null;
    }

    /** Werwölfe, dann die Sonderrollen, Rest Dorfbewohner. Mit Dieb zwei Dorfbewohner extra. */
    public static List<Role> cardsFor(int playerCount, Integer chosenCount, List<String> specialRoles) {
        Text problem = problem(playerCount, chosenCount, specialRoles);
        if (problem != null) {
            throw new GameException(problem);
        }
        int extra = specialRoles.contains(WerwolfRoles.THIEF) ? WerwolfRoles.THIEF_EXTRA_CARDS : 0;
        List<Role> cards = new ArrayList<>(playerCount + extra);
        for (int i = 0; i < werewolves(playerCount, chosenCount); i++) {
            cards.add(WerwolfRoles.byId(WerwolfRoles.WEREWOLF));
        }
        specialRoles.forEach(id -> cards.add(WerwolfRoles.byId(id)));
        while (cards.size() < playerCount + extra) {
            cards.add(WerwolfRoles.byId(WerwolfRoles.VILLAGER));
        }
        return cards;
    }

    public static Deal deal(int playerCount, Integer chosenCount, List<String> specialRoles, RandomGenerator random) {
        List<Role> cards = cardsFor(playerCount, chosenCount, specialRoles);
        Shuffle.inPlace(cards, random);
        return new Deal(List.copyOf(cards.subList(0, playerCount)), List.copyOf(cards.subList(playerCount, cards.size())));
    }
}
