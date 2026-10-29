import { defineConfig } from "vite";

// Relative Pfade, damit die Seite auch in einem Unterordner läuft
// (GitHub Pages: richard-kruschinski.github.io/AryntaSpielesammlung/)
export default defineConfig({
  base: "./",
  build: {
    rollupOptions: {
      input: {
        main: "index.html",
        impressum: "impressum.html",
        datenschutz: "datenschutz.html",
      },
    },
  },
});
