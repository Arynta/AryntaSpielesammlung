package de.kruschinski.werwolf.config;

import de.kruschinski.werwolf.game.GameType;
import de.kruschinski.werwolf.game.RoomRegistry;
import de.kruschinski.werwolf.ws.GameSocketHandler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.standard.ServletServerContainerFactoryBean;

import java.time.Duration;
import java.util.Set;

@Configuration
@EnableWebSocket
public class AppConfig implements WebSocketConfigurer, WebMvcConfigurer {

    /**
     * Von welchen Seiten aus sich das Frontend verbinden darf, kommagetrennt.
     * Lokal: http://localhost:5173. Auf Render setzt du ALLOWED_ORIGINS auf die Adresse deines Frontends.
     */
    private final String[] allowedOrigins;
    private final GameSocketHandler gameSocketHandler;

    public AppConfig(@Value("${app.allowed-origins}") String[] allowedOrigins,
                     GameSocketHandler gameSocketHandler) {
        this.allowedOrigins = allowedOrigins;
        this.gameSocketHandler = gameSocketHandler;
    }

    /**
     * {@code app.locked-games}: Spiele, die in der Lobby noch gesperrt sind ("Bald verfügbar").
     * {@code app.street-view.daily-limit}: so viele Google-Street-View-Viewer am Tag, 0 oder leer = nur Mapillary.
     */
    @Bean
    public static RoomRegistry roomRegistry(@Value("${app.locked-games:}") Set<GameType> lockedGames,
                                            @Value("${app.limits.rooms-per-address}") int maxRoomsPerAddress,
                                            @Value("${app.street-view.daily-limit:0}") Integer streetViewDailyLimit) {
        // Eine leer angelegte Umgebungsvariable kommt hier als null an
        return new RoomRegistry(lockedGames, maxRoomsPerAddress, streetViewDailyLimit == null ? 0 : streetViewDailyLimit);
    }

    /** Größere Nachrichten und stille Verbindungen beendet der Server selbst (Schutz vor Skripten). */
    @Bean
    public static ServletServerContainerFactoryBean webSocketContainer(
            @Value("${app.limits.max-message-bytes}") int maxMessageBytes,
            @Value("${app.limits.idle-timeout}") Duration idleTimeout) {
        ServletServerContainerFactoryBean container = new ServletServerContainerFactoryBean();
        container.setMaxTextMessageBufferSize(maxMessageBytes);
        container.setMaxBinaryMessageBufferSize(maxMessageBytes);
        container.setMaxSessionIdleTimeout(idleTimeout.toMillis());
        return container;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(gameSocketHandler, "/ws").setAllowedOriginPatterns(allowedOrigins);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/health").allowedOriginPatterns(allowedOrigins).allowedMethods("GET");
    }
}
