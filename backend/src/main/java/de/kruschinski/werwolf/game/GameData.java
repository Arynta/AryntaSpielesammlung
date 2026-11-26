package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.EnumMap;
import java.util.Map;

/**
 * Liest die Spieldaten (Wörter, Rollen), die Backend und Frontend gemeinsam nutzen. Jede Datei gibt es
 * auf Deutsch ({@code games/name.json}) und auf Englisch ({@code games/name-en.json}).
 */
final class GameData {

    private static final JsonMapper JSON = JsonMapper.builder()
            // In der JSON-Datei steht ein Schalter nur, wenn er an ist
            .disable(DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES)
            .build();

    private GameData() {
    }

    static <T> Map<Language, T> perLanguage(String name, Class<T> type) {
        Map<Language, T> files = new EnumMap<>(Language.class);
        files.put(Language.DE, read("games/" + name + ".json", type));
        files.put(Language.EN, read("games/" + name + "-en.json", type));
        return files;
    }

    static <T> T read(String resource, Class<T> type) {
        try (InputStream in = GameData.class.getClassLoader().getResourceAsStream(resource)) {
            if (in == null) {
                throw new IllegalStateException("Spieldaten fehlen: " + resource);
            }
            return JSON.readValue(in, type);
        } catch (IOException e) {
            throw new UncheckedIOException("Spieldaten nicht lesbar: " + resource, e);
        }
    }
}
