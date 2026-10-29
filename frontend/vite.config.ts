import { defineConfig, searchForWorkspaceRoot } from "vite";

// Relative Pfade, damit die Seite auch in einem Unterordner läuft
// (GitHub Pages: richard-kruschinski.github.io/AryntaSpielesammlung/)
export default defineConfig({
  base: "./",
  server: {
    fs: {
      // Wörter und Rollen liegen im Backend-Ordner, damit beide dieselbe Datei nutzen. Bilder liegen in assets/.
      allow: [searchForWorkspaceRoot(process.cwd()), "../backend/src/main/resources/games", "../assets"],
    },
  },
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
