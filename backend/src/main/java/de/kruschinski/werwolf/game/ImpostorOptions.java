package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Text;

/** Einstellungen einer Impostor-Runde, die der Host in der Lobby wählt. */
public record ImpostorOptions(int impostorCount, boolean impostorSeesCategory, boolean randomStartPlayer) {

    /** Mehr gibt es auch bei vollem Raum nicht. */
    public static final int MAX_IMPOSTORS = Room.MAX_PLAYERS / 2 - 1;

    public static final ImpostorOptions DEFAULT = new ImpostorOptions(1, true, true);

    public ImpostorOptions {
        if (impostorCount < 1 || impostorCount > MAX_IMPOSTORS) {
            throw new GameException("error.impostor.count", MAX_IMPOSTORS);
        }
    }

    /** Ab 2 Impostorn muss die Crew mindestens zwei mehr sein, sonst ist sie chancenlos. */
    public static int minParticipants(int impostorCount) {
        int minPlayers = GameType.IMPOSTOR.minPlayers();
        return impostorCount == 1 ? minPlayers : Math.max(minPlayers, 2 * impostorCount + 2);
    }

    /** Warum mit so vielen Mitspielern nicht gespielt werden kann, oder {@code null}. */
    public Text problem(int participantCount) {
        int needed = minParticipants(impostorCount);
        if (participantCount >= needed) {
            return null;
        }
        return impostorCount == 1
                ? Text.of("hint.impostor.minPlayers", needed)
                : Text.of("hint.impostor.minPlayersFor", impostorCount, needed);
    }

    public ImpostorOptions withImpostorSeesCategory(boolean value) {
        return new ImpostorOptions(impostorCount, value, randomStartPlayer);
    }
}
