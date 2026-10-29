package de.kruschinski.werwolf.ws;

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
 *   <li>{@code vote}: targetId</li>
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
        String targetId
) {
}
