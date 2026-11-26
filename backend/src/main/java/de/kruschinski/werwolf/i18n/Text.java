package de.kruschinski.werwolf.i18n;

import java.util.List;
import java.util.ResourceBundle;

/**
 * Ein Text, der erst beim Empfänger in dessen Sprache fertig wird. Die Vorlagen stehen in
 * {@code i18n/messages*.properties}, Platzhalter wie bei {@link String#format}. Ein Argument, das selbst
 * ein {@code Text} ist, wird in derselben Sprache eingesetzt.
 */
public record Text(String key, List<Object> args) {

    private static final ResourceBundle.Control NO_FALLBACK =
            ResourceBundle.Control.getNoFallbackControl(ResourceBundle.Control.FORMAT_PROPERTIES);

    public static Text of(String key, Object... args) {
        return new Text(key, List.of(args));
    }

    public String in(Language language) {
        String template = ResourceBundle.getBundle("i18n/messages", language.locale(), NO_FALLBACK).getString(key);
        Object[] values = args.stream().map(a -> a instanceof Text t ? t.in(language) : a).toArray();
        return String.format(language.locale(), template, values);
    }
}
