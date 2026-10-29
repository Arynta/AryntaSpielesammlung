package de.kruschinski.werwolf.config;

import de.kruschinski.werwolf.game.RoomRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

/** Räumt alle 10 Minuten Räume weg, in denen seit 6 Stunden nichts passiert ist. */
@Component
public class RoomCleanup {

    private static final Logger log = LoggerFactory.getLogger(RoomCleanup.class);

    private final RoomRegistry rooms;

    public RoomCleanup(RoomRegistry rooms) {
        this.rooms = rooms;
    }

    @Scheduled(fixedRate = 10 * 60 * 1000)
    public void removeIdleRooms() {
        int removed = rooms.removeIdleRooms(Duration.ofHours(6));
        if (removed > 0) {
            log.info("{} alte Räume entfernt, {} noch offen", removed, rooms.size());
        }
    }
}
