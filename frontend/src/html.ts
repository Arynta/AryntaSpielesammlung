/** Macht Text sicher für innerHTML: Namen und Wörter kommen von Mitspielern. */
export function esc(text: string): string {
  return text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}
