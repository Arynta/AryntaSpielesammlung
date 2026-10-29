package de.kruschinski.werwolf.game;

import java.util.Collections;
import java.util.List;
import java.util.random.RandomGenerator;

final class Shuffle {

    private Shuffle() {
    }

    /** Fisher-Yates, damit wir einen beliebigen RandomGenerator (auch einen festen für Tests) nutzen können. */
    static <T> void inPlace(List<T> list, RandomGenerator random) {
        for (int i = list.size() - 1; i > 0; i--) {
            Collections.swap(list, i, random.nextInt(i + 1));
        }
    }
}
