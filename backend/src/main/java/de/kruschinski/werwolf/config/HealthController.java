package de.kruschinski.werwolf.config;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Render prüft hierüber, ob der Server läuft. Das Frontend ruft es auf, um den Server aufzuwecken. */
@RestController
public class HealthController {

    @GetMapping("/health")
    public String health() {
        return "ok";
    }
}
