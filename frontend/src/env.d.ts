interface ImportMetaEnv {
  readonly VITE_BACKEND_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

// Vite bindet CSS-Dateien per import ein
declare module "*.css";

// Bilder liefert Vite als URL
declare module "*.png" {
  const url: string;
  export default url;
}
