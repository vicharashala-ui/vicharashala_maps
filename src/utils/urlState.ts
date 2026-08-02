// §3.13: history.replaceState only, never pushState. 300ms debounce scoped to the
// replaceState call itself — callers apply UI/map changes synchronously, then call this.
let timer: ReturnType<typeof setTimeout> | null = null;

export function debouncedUpdateUrl(params: { river?: string | null; pa?: string | null }): void {
  if (timer) clearTimeout(timer);
  timer = setTimeout(() => {
    const url = new URL(location.href);
    if (params.river) {
      url.searchParams.set('river', params.river);
      url.searchParams.delete('pa');
    } else if (params.pa) {
      url.searchParams.set('pa', params.pa);
      url.searchParams.delete('river');
    } else {
      url.searchParams.delete('river');
      url.searchParams.delete('pa');
    }
    history.replaceState(null, '', url);
  }, 300);
}

export function readInitialSelection(): { riverId: string | null; paId: string | null } {
  const params = new URLSearchParams(location.search);
  return { riverId: params.get('river'), paId: params.get('pa') };
}
