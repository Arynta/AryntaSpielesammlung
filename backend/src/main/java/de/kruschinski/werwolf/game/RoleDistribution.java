package de.kruschinski.werwolf.game;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.random.RandomGenerator;

/** Legt fest, welche Rollen es bei wie vielen Spielern gibt. Hier kannst du später neue Rollen einbauen. */
public final class RoleDistribution {

    private RoleDistribution() {
    }

    /** Ein Werwolf pro angefangene vier Spieler (4–7 → 1, 8–11 → 2, ...), immer eine Seherin, Rest Dorfbewohner. */
    public static List<Role> rolesFor(int playerCount) {
        if (playerCount < Room.MIN_PLAYERS) {
            throw new GameException("Es werden mindestens " + Room.MIN_PLAYERS + " Spieler gebraucht.");
        }
        int werewolves = Math.max(1, playerCount / 4);

        List<Role> roles = new ArrayList<>(playerCount);
        for (int i = 0; i < werewolves; i++) {
            roles.add(Role.WERWOLF);
        }
        roles.add(Role.SEHERIN);
        while (roles.size() < playerCount) {
            roles.add(Role.DORFBEWOHNER);
        }
        return roles;
    }

    public static List<Role> shuffledRolesFor(int playerCount, RandomGenerator random) {
        List<Role> roles = rolesFor(playerCount);
        // Fisher-Yates, damit wir einen beliebigen RandomGenerator (auch einen festen für Tests) nutzen können
        for (int i = roles.size() - 1; i > 0; i--) {
            Collections.swap(roles, i, random.nextInt(i + 1));
        }
        return roles;
    }
}
