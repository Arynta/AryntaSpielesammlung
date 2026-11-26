package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;

/**
 * Die Fragen für Nobody is Perfect. Sie stehen in {@code games/nobody-is-perfect-questions*.json},
 * damit der lokale Modus im Frontend dieselben Fragen nutzt.
 */
public final class NobodyIsPerfectQuestions {

    /** Eine kuriose Frage und die echte Antwort darauf. */
    public record Question(String question, String answer) {
    }

    private record QuestionFile(List<Question> questions) {
    }

    private static final Map<Language, QuestionFile> FILES =
            GameData.perLanguage("nobody-is-perfect-questions", QuestionFile.class);

    private NobodyIsPerfectQuestions() {
    }

    public static List<Question> all(Language language) {
        return FILES.get(language).questions();
    }

    /** Zieht {@code count} Fragen, die noch nicht dran waren. Reichen die nicht, kommen auch alte wieder. */
    static List<Question> pick(Language language, int count, Collection<String> used, RandomGenerator random) {
        List<Question> questions = all(language);
        List<Question> fresh = new ArrayList<>(questions.stream().filter(q -> !used.contains(q.question())).toList());
        List<Question> old = new ArrayList<>(questions.stream().filter(q -> used.contains(q.question())).toList());
        Shuffle.inPlace(fresh, random);
        Shuffle.inPlace(old, random);
        fresh.addAll(old);
        return List.copyOf(fresh.subList(0, Math.min(count, fresh.size())));
    }
}
