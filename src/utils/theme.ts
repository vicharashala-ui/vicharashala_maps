// Resolves the active theme the same way the MapLibre layers do (§5.6): read the computed
// --color-land value rather than re-deriving light/dark from localStorage + prefers-color-scheme
// ourselves, so this can never disagree with what's actually painted on screen.
export function isDarkTheme(): boolean {
  if (typeof document === 'undefined') return false;
  const land = getComputedStyle(document.documentElement).getPropertyValue('--color-land').trim();
  return land.toLowerCase() === '#1e3a2f';
}
