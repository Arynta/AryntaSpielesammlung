package de.kruschinski.werwolf.ws;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConnectionGuardTest {

    /** Uhr, die man von Hand vorstellen kann. */
    private static final class TestClock extends Clock {
        private Instant now = Instant.parse("2026-11-27T18:00:00Z");

        void advance(Duration duration) {
            now = now.plus(duration);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    private final TestClock clock = new TestClock();

    @Test
    void zuVieleNachrichtenInEinerSekundeWerdenAbgelehnt() {
        ConnectionGuard guard = new ConnectionGuard(clock, 3, 10);
        assertTrue(guard.allowMessage());
        assertTrue(guard.allowMessage());
        assertTrue(guard.allowMessage());
        assertFalse(guard.allowMessage());
    }

    @Test
    void naechsteSekundeDarfWiederGesendetWerden() {
        ConnectionGuard guard = new ConnectionGuard(clock, 2, 10);
        guard.allowMessage();
        guard.allowMessage();
        assertFalse(guard.allowMessage());
        clock.advance(Duration.ofSeconds(1));
        assertTrue(guard.allowMessage());
    }

    @Test
    void ratenVonRaumcodesWirdGestoppt() {
        ConnectionGuard guard = new ConnectionGuard(clock, 20, 3);
        assertTrue(guard.allowUnknownCode());
        assertTrue(guard.allowUnknownCode());
        assertFalse(guard.allowUnknownCode());
    }

    @Test
    void nachEinemTrefferBeginntDasZaehlenNeu() {
        ConnectionGuard guard = new ConnectionGuard(clock, 20, 3);
        guard.allowUnknownCode();
        guard.allowUnknownCode();
        guard.joined();
        assertTrue(guard.allowUnknownCode());
        assertTrue(guard.allowUnknownCode());
    }
}
