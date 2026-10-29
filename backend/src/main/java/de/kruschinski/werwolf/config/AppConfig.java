package de.kruschinski.werwolf.config;

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

    @Bean
    public static RoomRegistry roomRegistry() {
        return new RoomRegistry();
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
