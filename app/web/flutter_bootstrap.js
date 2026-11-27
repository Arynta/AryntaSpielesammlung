{{flutter_js}}
{{flutter_build_config}}

// Zweite Sicherung gegen eingeschleuste Skripte: nur Code von dieser Seite selbst darf laufen.
// 'wasm-unsafe-eval' braucht Flutters Zeichen-Engine (CanvasKit), Inline-Styles setzt Flutter selbst.
// Nur im Release: Der Debug-Modus von "flutter run" arbeitet mit Inline-Skripten.
// Ausnahme Google: Für Geo-Bingo mit Google Street View lädt der Browser die Maps JavaScript API,
// ihre Bilder, Schriften und Styles von Google (siehe docs/entscheidungen.md, Abschnitt 5).
// Achtung: Hier keine globalen Namen wie "google" anlegen, die überdecken sonst window.google der Maps-API.
const debugBuild = _flutter.buildConfig.builds.some((build) => build.compileTarget === "dartdevc");
if (!debugBuild) {
  const googleHosts = "https://*.googleapis.com https://*.gstatic.com";
  const policy = document.createElement("meta");
  policy.httpEquiv = "Content-Security-Policy";
  policy.content = [
    "default-src 'self'",
    `script-src 'self' 'wasm-unsafe-eval' ${googleHosts}`,
    `style-src 'self' 'unsafe-inline' ${googleHosts}`,
    `font-src 'self' data: ${googleHosts}`,
    `img-src 'self' data: blob: ${googleHosts} https://*.google.com https://*.ggpht.com https://*.googleusercontent.com`,
    "connect-src 'self' data: blob: http: https: ws: wss:",
    "worker-src 'self' blob:",
    "manifest-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'none'",
  ].join("; ");
  document.head.append(policy);
}

// Alles kommt vom eigenen Server: keine Zeichen-Engine und keine Ersatzschriften von Google.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    fontFallbackBaseUrl: "ersatzschriften/",
  },
});
