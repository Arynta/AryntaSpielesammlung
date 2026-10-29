package de.kruschinski.werwolf.game;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Alle Werwolf-Rollen. Sie stehen in {@code games/werwolf-roles.json}, damit der lokale Modus
 * im Frontend dieselben Rollen und Texte nutzt.
 */
public final class WerwolfRoles {

    public static final String VILLAGER = "DORFBEWOHNER";
    public static final String WEREWOLF = "WERWOLF";
    public static final String SEER = "SEHERIN";
    /** Mit Dieb kommen zwei Karten mehr ins Spiel, aus denen er tauschen darf. */
    public static final String THIEF = "DIEB";
    public static final int THIEF_EXTRA_CARDS = 2;

    private record Team(String id, String name) {
    }

    private record RoleFile(List<Team> teams, List<Role> roles) {
    }

    private static final RoleFile FILE = GameData.read("games/werwolf-roles.json", RoleFile.class);
    private static final Map<String, Role> BY_ID = FILE.roles().stream()
            .collect(Collectors.toMap(Role::id, Function.identity()));
    private static final Map<String, String> TEAM_NAMES = FILE.teams().stream()
            .collect(Collectors.toMap(Team::id, Team::name));

    private WerwolfRoles() {
    }

    public static Role byId(String id) {
        Role role = BY_ID.get(id);
        if (role == null) {
            throw new GameException("Die Rolle \"" + id + "\" gibt es nicht.");
        }
        return role;
    }

    public static String teamName(String teamId) {
        return TEAM_NAMES.getOrDefault(teamId, teamId);
    }

    /** Rollen, die einzeln angekreuzt werden. Dorfbewohner füllen auf, Werwölfe werden gezählt. */
    public static List<Role> specialRoles() {
        return FILE.roles().stream()
                .filter(r -> !r.id().equals(VILLAGER) && !r.id().equals(WEREWOLF))
                .toList();
    }

    /** Prüft die Auswahl und bringt sie in die feste Reihenfolge der Rollenliste. */
    public static List<String> normalizeSpecialRoles(Collection<String> ids) {
        if (ids == null) {
            throw new GameException("Bitte gib die Rollen an.");
        }
        List<String> known = specialRoles().stream().map(Role::id).toList();
        if (!known.containsAll(ids)) {
            throw new GameException("Diese Rolle kann man nicht auswählen.");
        }
        return known.stream().filter(ids::contains).toList();
    }
}
