package de.kruschinski.werwolf.i18n;

import java.util.Locale;

/** Sprache eines Handys. Auf der Leitung klein geschrieben ("de", "en"). */
public enum Language {
    DE, EN;

    /** Unbekannt oder fehlend heißt Deutsch, damit ältere Handys weiter funktionieren. */
    public static Language parse(String raw) {
        return raw != null && raw.strip().equalsIgnoreCase("en") ? EN : DE;
    }

    public Locale locale() {
        return Locale.forLanguageTag(name().toLowerCase(Locale.ROOT));
    }
}
