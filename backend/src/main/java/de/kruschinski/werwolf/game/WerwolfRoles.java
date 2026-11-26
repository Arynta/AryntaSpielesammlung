package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * Alle Werwolf-Rollen. Sie stehen in {@code games/werwolf-roles*.json}, damit der lokale Modus
 * im Frontend dieselben Rollen und Texte nutzt. Die Spiellogik arbeitet mit den IDs, Namen und
 * Beschreibungen kommen erst in der Ansicht in der Sprache des Spielers dazu.
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

    private static final Map<Language, RoleFile> FILES = GameData.perLanguage("werwolf-roles", RoleFile.class);

    private WerwolfRoles() {
    }

    public static Role byId(String id) {
        return byId(id, Language.DE);
    }

    public static Role byId(String id, Language language) {
        return FILES.get(language).roles().stream()
                .filter(r -> r.id().equals(id))
                .findFirst()
                .orElseThrow(() -> new GameException("error.werwolf.unknownRole", id));
    }

    public static String teamName(String teamId) {
        return teamName(teamId, Language.DE);
    }

    public static String teamName(String teamId, Language language) {
        return FILES.get(language).teams().stream()
                .filter(t -> t.id().equals(teamId))
                .map(Team::name)
                .findFirst()
                .orElse(teamId);
    }

    /** Rollen, die einzeln angekreuzt werden. Dorfbewohner füllen auf, Werwölfe werden gezählt. */
    public static List<Role> specialRoles() {
        return specialRoles(Language.DE);
    }

    public static List<Role> specialRoles(Language language) {
        return FILES.get(language).roles().stream()
                .filter(r -> !r.id().equals(VILLAGER) && !r.id().equals(WEREWOLF))
                .toList();
    }

    /** Prüft die Auswahl und bringt sie in die feste Reihenfolge der Rollenliste. */
    public static List<String> normalizeSpecialRoles(Collection<String> ids) {
        if (ids == null) {
            throw new GameException("error.werwolf.noRoles");
        }
        List<String> known = specialRoles().stream().map(Role::id).toList();
        if (!known.containsAll(ids)) {
            throw new GameException("error.werwolf.roleNotSelectable");
        }
        return known.stream().filter(ids::contains).toList();
    }
}
