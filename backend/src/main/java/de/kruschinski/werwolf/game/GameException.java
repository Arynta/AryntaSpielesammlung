package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;
import de.kruschinski.werwolf.i18n.Text;

/** Fehler, deren Text direkt beim Spieler angezeigt werden darf, in seiner Sprache. */
public class GameException extends RuntimeException {

    private final transient Text text;

    public GameException(String key, Object... args) {
        this(Text.of(key, args));
    }

    public GameException(Text text) {
        super(text.in(Language.DE));
        this.text = text;
    }

    public String messageIn(Language language) {
        return text.in(language);
    }
}
