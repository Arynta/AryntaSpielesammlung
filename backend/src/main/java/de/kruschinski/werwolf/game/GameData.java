package de.kruschinski.werwolf.game;

import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;

/** Liest die Spieldaten (Wörter, Rollen), die Backend und Frontend gemeinsam nutzen. */
final class GameData {

    private static final JsonMapper JSON = JsonMapper.builder()
            // In der JSON-Datei steht ein Schalter nur, wenn er an ist
            .disable(DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES)
            .build();

    private GameData() {
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
