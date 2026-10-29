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
    private final Map<String, Role> rolesByPlayerId = new HashMap<>();
    private Phase phase = Phase.NIGHT;
    private int round = 1;

    WerwolfGame(List<Player> players, RandomGenerator random) {
        this.players = List.copyOf(players);
        List<Role> roles = RoleDistribution.shuffledRolesFor(players.size(), random);
        for (int i = 0; i < players.size(); i++) {
            rolesByPlayerId.put(players.get(i).id(), roles.get(i));
        }
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
        Role role = roleOf(playerId);
        if (role == null) {
            return null;
        }
        List<String> fellowWerewolves = List.of();
        if (role == Role.WERWOLF) {
            fellowWerewolves = players.stream()
                    .filter(p -> roleOf(p.id()) == Role.WERWOLF && !p.id().equals(playerId))
                    .map(Player::name)
                    .toList();
        }
        return new RoomView.WerwolfView(role, role.displayName(), role.description(), fellowWerewolves);
    }
}
