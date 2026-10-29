package de.kruschinski.werwolf.game;

/**
 * Eine Werwolf-Rolle aus {@code games/werwolf-roles.json}.
 *
 * @param wolfPack     wacht mit den Wölfen auf: kennt die anderen aus dem Rudel und wird von ihnen erkannt
 * @param seesWolfPack kennt das Rudel, wird von ihm aber nicht erkannt (Günstling)
 */
public record Role(String id, String name, String team, String description, boolean wolfPack, boolean seesWolfPack) {
}
