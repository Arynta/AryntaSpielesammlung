package de.kruschinski.werwolf.game;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;

/**
 * Werwolf: Rollen werden geheim verteilt, die Spielleitung schaltet zwischen Nacht und Tag um.
 * Gesprochen und abgestimmt wird am Tisch. Nicht threadsicher, {@link Room} synchronisiert.
 */
public final class WerwolfGame implements Game {

    private final List<Player> players;
    private final String gameMasterId;
    private final Map<String, Role> rolesByPlayerId = new HashMap<>();
    private final List<Role> leftover;
    private Phase phase = Phase.NIGHT;
    private int round = 1;

    /**
     * @param players      alle, die eine Rolle bekommen (ohne Spielleitung)
     * @param gameMasterId Host, der nur leitet und alle Rollen sieht, oder {@code null}
     */
    WerwolfGame(List<Player> players, String gameMasterId, Integer werewolfCount, List<String> specialRoles,
                RandomGenerator random) {
        this.players = List.copyOf(players);
        this.gameMasterId = gameMasterId;
        RoleDistribution.Deal deal = RoleDistribution.deal(players.size(), werewolfCount, specialRoles, random);
        for (int i = 0; i < players.size(); i++) {
            rolesByPlayerId.put(players.get(i).id(), deal.perPlayer().get(i));
        }
        this.leftover = deal.leftover();
    }

    @Override
    public GameType type() {
        return GameType.WERWOLF;
    }

    @Override
    public Phase phase() {
        return phase;
    }

    @Override
    public int round() {
        return round;
    }

    @Override
    public boolean betweenRounds() {
        return false;
    }

    public Role roleOf(String playerId) {
        return rolesByPlayerId.get(playerId);
    }

    public List<Role> leftover() {
        return leftover;
    }

    /**
     * Schaltet zwischen Nacht und Tag um. Das ist die Stelle, an der du die eigentlichen
     * Spielregeln einbaust (Abstimmungen auswerten, Opfer bestimmen, Siegbedingung prüfen).
     */
    void nextPhase() {
        if (phase == Phase.NIGHT) {
            phase = Phase.DAY;
        } else {
            phase = Phase.NIGHT;
            round++;
        }
    }

    RoomView.WerwolfView viewFor(String playerId) {
        if (playerId.equals(gameMasterId)) {
            List<RoomView.RoleAssignment> overview = players.stream()
                    .map(p -> assignment(p, roleOf(p.id())))
                    .toList();
            return new RoomView.WerwolfView(true, null, List.of(), roleNames(leftover), overview);
        }
        Role role = roleOf(playerId);
        if (role == null) {
            return null;
        }
        List<String> thiefChoices = role.id().equals(WerwolfRoles.THIEF) ? roleNames(leftover) : List.of();
        return new RoomView.WerwolfView(false, RoomView.RoleCard.of(role), knownWolves(playerId, role), thiefChoices, null);
    }

    /** Das Rudel kennt sich gegenseitig, der Günstling kennt das Rudel. */
    private List<String> knownWolves(String playerId, Role role) {
        if (!role.wolfPack() && !role.seesWolfPack()) {
            return List.of();
        }
        return players.stream()
                .filter(p -> !p.id().equals(playerId) && roleOf(p.id()).wolfPack())
                .map(Player::name)
                .toList();
    }

    private static RoomView.RoleAssignment assignment(Player player, Role role) {
        return new RoomView.RoleAssignment(player.id(), player.name(), RoomView.RoleCard.of(role));
    }

    private static List<String> roleNames(List<Role> roles) {
        return roles.stream().map(Role::name).toList();
    }
}
