package de.kruschinski.werwolf.game;

import java.util.regex.Pattern;

/** Woher die Straßenbilder einer Geo-Bingo-Runde kommen. Alle in der Runde nutzen dieselbe Quelle. */
public enum StreetViewSource {

    /** Google Street View. Panorama-IDs bestehen aus Buchstaben, Ziffern, {@code -} und {@code _}. */
    GOOGLE("[A-Za-z0-9_-]{10,100}"),
    /** Mapillary. Bild-IDs sind Zahlen. */
    MAPILLARY("\\d{1,20}");

    private final Pattern imageId;

    StreetViewSource(String imageId) {
        this.imageId = Pattern.compile(imageId);
    }

    /** Ob die App ein Bild mit dieser ID aus dieser Quelle anzeigen kann. */
    boolean accepts(String id) {
        return id != null && imageId.matcher(id).matches();
    }
}
