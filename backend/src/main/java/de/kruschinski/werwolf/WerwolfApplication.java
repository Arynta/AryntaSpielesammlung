package de.kruschinski.werwolf;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class WerwolfApplication {

    public static void main(String[] args) {
        SpringApplication.run(WerwolfApplication.class, args);
    }
}
