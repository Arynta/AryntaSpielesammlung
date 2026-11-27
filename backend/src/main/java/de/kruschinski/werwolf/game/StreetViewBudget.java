package de.kruschinski.werwolf.game;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;

/**
 * Tageslimit für Google Street View. Google rechnet jeden neu geöffneten Viewer einzeln ab und schenkt
 * nur ein Kontingent pro Monat. Deshalb bucht der Server vor jeder Google-Runde die Viewer, die dafür
 * neu geöffnet werden. Passt das nicht mehr ins Limit, läuft die Runde mit Mapillary.
 *
 * <p>Der Zähler liegt nur im Speicher und fängt nach einem Neustart bei null an. Google selbst bietet
 * kein Tageskontingent für Street View, die übrigen Sicherungen stehen in docs/entscheidungen.md.
 * Threadsicher.
 */
public final class StreetViewBudget {

    /** Google setzt die Tageskontingente um Mitternacht pazifischer Zeit zurück, also hier auch. */
    private static final ZoneId GOOGLE_DAY = ZoneId.of("America/Los_Angeles");

    private final Clock clock;
    private final int dailyLimit;
    private LocalDate day;
    private int used;

    /** {@code dailyLimit} 0 heißt: Google ist aus, alle Runden laufen mit Mapillary. */
    public StreetViewBudget(Clock clock, int dailyLimit) {
        if (dailyLimit < 0) {
            throw new IllegalArgumentException("Das Tageslimit darf nicht negativ sein: " + dailyLimit);
        }
        this.clock = clock;
        this.dailyLimit = dailyLimit;
    }

    /** Ohne Google, für Tests und wenn nichts eingestellt ist. */
    public static StreetViewBudget off() {
        return new StreetViewBudget(Clock.systemUTC(), 0);
    }

    public boolean enabled() {
        return dailyLimit > 0;
    }

    /** Bucht {@code viewers} neue Viewer, aber nur, wenn alle heute noch ins Limit passen. */
    public synchronized boolean reserve(int viewers) {
        if (!enabled()) {
            return false;
        }
        rollOver();
        if (used + viewers > dailyLimit) {
            return false;
        }
        used += viewers;
        return true;
    }

    public synchronized int usedToday() {
        rollOver();
        return used;
    }

    private void rollOver() {
        LocalDate today = LocalDate.ofInstant(clock.instant(), GOOGLE_DAY);
        if (!today.equals(day)) {
            day = today;
            used = 0;
        }
    }
}
