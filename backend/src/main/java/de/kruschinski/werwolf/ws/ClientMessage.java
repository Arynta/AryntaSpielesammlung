package de.kruschinski.werwolf.ws;

import java.util.List;

/**
 * Nachricht vom Handy an den Server. Je nach {@code type} sind nur manche Felder gefüllt.
 *
 * <ul>
 *   <li>{@code create}: name</li>
 *   <li>{@code join}: code, name</li>
 *   <li>{@code rejoin}: code, secret (nach Neuladen der Seite)</li>
 *   <li>{@code selectGame}: game (z. B. "IMPOSTOR")</li>
 *   <li>{@code setReady}: ready</li>
 *   <li>{@code configureImpostor}: impostorSeesCategory, customWord (leer = Wortliste)</li>
 *   <li>{@code vote}, {@code kick}: targetId</li>
 *   <li>{@code setPlayerLimit}: playerLimit</li>
 *   <li>{@code setImpostorCategories}: categories</li>
 *   <li>{@code setImpostorOptions}: impostorCount, randomStartPlayer</li>
 *   <li>{@code configureWerwolf}: werewolfCount (fehlt = automatisch), roles, hostIsGameMaster</li>
 *   <li>{@code configureTabu}: turnSeconds, autoTeams, teamCount, targetScore</li>
 *   <li>{@code chooseTeam}: team, targetId (nur Host, um andere zu verschieben)</li>
 *   <li>{@code startTurn}, {@code wordCorrect}, {@code wordSkip}, {@code buzz}: keine Felder</li>
 *   <li>{@code leave}, {@code start}, {@code nextPhase}, {@code startVoting}, {@code nextRound},
 *       {@code backToLobby}, {@code ping}: keine Felder</li>
 * </ul>
 */
public record ClientMessage(
        String type,
        String name,
        String code,
        String secret,
        String game,
        Boolean ready,
        Boolean impostorSeesCategory,
        String customWord,
        String targetId,
        Integer playerLimit,
        List<String> categories,
        Integer impostorCount,
        Boolean randomStartPlayer,
        Integer werewolfCount,
        List<String> roles,
        Boolean hostIsGameMaster,
        Integer turnSeconds,
        Boolean autoTeams,
        Integer teamCount,
        Integer targetScore,
        Integer team
) {
}
