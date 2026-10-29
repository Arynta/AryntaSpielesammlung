package de.kruschinski.werwolf.game;

/**
 * Ein Spieler in einem Raum.
 *
 * <p>{@code id} ist öffentlich und wird allen Mitspielern geschickt.
 * {@code secret} kennt nur das Handy des Spielers selbst. Damit meldet es sich
 * nach einem Neuladen der Seite wieder an.
 */
public class Player {

    private final String id;
    private final String secret;
    private final String name;
    private boolean alive = true;
    private boolean connected = true;
    private boolean ready;

    Player(String id, String secret, String name) {
        this.id = id;
        this.secret = secret;
        this.name = name;
    }

    public String id() {
        return id;
    }

    public String secret() {
        return secret;
    }

    public String name() {
        return name;
    }

    public boolean alive() {
        return alive;
    }

    void setAlive(boolean alive) {
        this.alive = alive;
    }

    public boolean connected() {
        return connected;
    }

    void setConnected(boolean connected) {
        this.connected = connected;
    }

    public boolean ready() {
        return ready;
    }

    void setReady(boolean ready) {
        this.ready = ready;
    }
}
