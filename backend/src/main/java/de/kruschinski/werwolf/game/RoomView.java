package de.kruschinski.werwolf.game;

import java.util.List;

/**
 * Das, was ein bestimmter Spieler vom Raum sehen darf.
 * Jeder Spieler bekommt seine eigene Ansicht, damit Rollen geheim bleiben.
 */
public record RoomView(
        String code,
        Phase phase,
        int round,
        String hostId,
        List<PlayerView> players,
        You you
) {

    /** Öffentliche Infos über einen Mitspieler (ohne Rolle!). */
    public record PlayerView(String id, String name, boolean alive, boolean connected) {
    }

    /** Infos nur für den Spieler selbst. */
    public record You(
            String id,
            String name,
            boolean host,
            Role role,
            String roleName,
            String roleDescription,
            List<String> fellowWerewolves
    ) {
    }
}
