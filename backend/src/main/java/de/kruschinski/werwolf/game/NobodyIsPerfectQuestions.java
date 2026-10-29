package de.kruschinski.werwolf.game;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.random.RandomGenerator;

/**
 * Die Fragen für Nobody is Perfect. Sie stehen in {@code games/nobody-is-perfect-questions.json},
 * damit der lokale Modus im Frontend dieselben Fragen nutzt.
 */
public final class NobodyIsPerfectQuestions {

    /** Eine kuriose Frage und die echte Antwort darauf. */
    public record Question(String question, String answer) {
    }

    private record QuestionFile(List<Question> questions) {
    }

    private static final List<Question> QUESTIONS =
            GameData.read("games/nobody-is-perfect-questions.json", QuestionFile.class).questions();

    private NobodyIsPerfectQuestions() {
    }

    public static List<Question> all() {
        return QUESTIONS;
    }

    /** Zieht {@code count} Fragen, die noch nicht dran waren. Reichen die nicht, kommen auch alte wieder. */
    static List<Question> pick(int count, Collection<String> used, RandomGenerator random) {
        List<Question> fresh = new ArrayList<>(QUESTIONS.stream().filter(q -> !used.contains(q.question())).toList());
        List<Question> old = new ArrayList<>(QUESTIONS.stream().filter(q -> used.contains(q.question())).toList());
        Shuffle.inPlace(fresh, random);
        Shuffle.inPlace(old, random);
        fresh.addAll(old);
        return List.copyOf(fresh.subList(0, Math.min(count, fresh.size())));
    }
}
