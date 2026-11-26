package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;
import de.kruschinski.werwolf.i18n.Text;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Properties;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LanguageTest {

    private final Clock clock = Clock.fixed(Instant.parse("2026-11-26T18:00:00Z"), ZoneOffset.UTC);

    private Room lobby(String... names) {
        Room room = new Room("TEST", clock);
        for (String name : names) {
            room.addPlayer(name);
        }
        return room;
    }

    @Test
    void unbekannteSpracheIstDeutsch() {
        assertEquals(Language.EN, Language.parse("en"));
        assertEquals(Language.DE, Language.parse("de"));
        assertEquals(Language.DE, Language.parse(null));
        assertEquals(Language.DE, Language.parse("fr"));
    }

    @Test
    void beideSprachdateienHabenDieselbenSchluessel() throws IOException {
        assertEquals(load("i18n/messages.properties").keySet(), load("i18n/messages_en.properties").keySet());
    }

    @Test
    void jederSiehtDieLobbyInSeinerSprache() {
        Room room = lobby("Anna", "Ben");
        room.setLanguage("p2", Language.EN);

        RoomView german = room.viewFor("p1");
        RoomView english = room.viewFor("p2");
        assertEquals("Noch 1 Spieler, dann kann es losgehen.", german.startHint());
        assertEquals("Still missing: 1 player(s), then you can start.", english.startHint());
        assertEquals("Werwolf", german.games().getFirst().name());
        assertEquals("Werewolf", english.games().getFirst().name());
        assertEquals("Tiere", german.impostorSettings().categoryNames().getFirst());
        assertEquals("Animals", english.impostorSettings().categoryNames().getFirst());
        assertEquals(german.impostorSettings().allCategories(), english.impostorSettings().allCategories());
    }

    @Test
    void fehlermeldungGibtEsInBeidenSprachen() {
        Room room = lobby("Anna");
        GameException error = assertThrows(GameException.class, () -> room.addPlayer("anna"));
        assertEquals("Der Name \"anna\" ist schon vergeben.", error.getMessage());
        assertEquals("The name \"anna\" is already taken.", error.messageIn(Language.EN));
    }

    @Test
    void textImTextWirdMitUebersetzt() {
        Text locked = Text.of("hint.locked", GameType.GEO_BINGO.displayName());
        assertEquals("Geo-Bingo ist bald verfügbar.", locked.in(Language.DE));
        assertEquals("Geo Bingo is coming soon.", locked.in(Language.EN));
    }

    @Test
    void spielinhalteKommenInDerSpracheDerSpielleitung() {
        Room room = lobby("Anna", "Ben", "Carl");
        room.setLanguage("p1", Language.EN);
        room.players().forEach(p -> room.setReady(p.id(), true));
        room.start("p1", new Random(1));

        ImpostorWords.SecretWord secret = ((ImpostorGame) room.game()).secret();
        assertTrue(ImpostorWords.allWords(Language.EN).contains(secret), secret.word());
    }

    @Test
    void rollenkarteInDerSpracheDesSpielers() {
        Room room = lobby("Anna", "Ben", "Carl", "Dora");
        room.setLanguage("p2", Language.EN);
        room.selectGame("p1", GameType.WERWOLF);
        room.configureWerwolf("p1", 1, java.util.List.of(), false);
        room.players().forEach(p -> room.setReady(p.id(), true));
        room.start("p1", new Random(1));

        WerwolfGame game = (WerwolfGame) room.game();
        RoomView.RoleCard card = room.viewFor("p2").werwolf().role();
        assertEquals(WerwolfRoles.byId(game.roleOf("p2").id(), Language.EN).name(), card.name());
        assertEquals(WerwolfRoles.byId(game.roleOf("p1").id()).name(), room.viewFor("p1").werwolf().role().name());
    }

    private static Properties load(String resource) throws IOException {
        Properties properties = new Properties();
        try (InputStream in = LanguageTest.class.getClassLoader().getResourceAsStream(resource)) {
            properties.load(in);
        }
        return properties;
    }
}
