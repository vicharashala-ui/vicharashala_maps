// §3.13: history.replaceState only, never pushState. 300ms debounce scoped to the
// replaceState call itself — callers apply UI/map changes synchronously, then call this.
let timer: ReturnType<typeof setTimeout> | null = null;

export function debouncedUpdateUrl(params: { river?: string | null; pa?: string | null; state?: string | null }): void {
  if (timer) clearTimeout(timer);
  timer = setTimeout(() => {
    const url = new URL(location.href);
    if (params.river) {
      url.searchParams.set('river', params.river);
      url.searchParams.delete('pa');
      url.searchParams.delete('state');
    } else if (params.pa) {
      url.searchParams.set('pa', params.pa);
      url.searchParams.delete('river');
      url.searchParams.delete('state');
    } else if (params.state) {
      url.searchParams.set('state', params.state);
      url.searchParams.delete('river');
      url.searchParams.delete('pa');
    } else {
      url.searchParams.delete('river');
      url.searchParams.delete('pa');
      url.searchParams.delete('state');
    }
    history.replaceState(null, '', url);
  }, 300);
}

export function readInitialSelection(): { riverId: string | null; paId: string | null; stateId: string | null } {
  const params = new URLSearchParams(location.search);
  return { riverId: params.get('river'), paId: params.get('pa'), stateId: params.get('state') };
}

// Filter params (§3.6) are orthogonal to selection params above — own debounce timer, own
// URL keys, never touches river/pa/state. Comma-joined lists per the spec's URL table
// (`pa-categories=np,tr`); a param is set only when its list/value is non-empty/non-null.
export interface FilterUrlParams {
  riverStates?: string[];
  basins?: string[];
  drainageType?: string | null;
  transnational?: boolean;
  paCategories?: string[];
  paStates?: string[];
}

let filterTimer: ReturnType<typeof setTimeout> | null = null;

function setListParam(url: URL, key: string, values: string[] | undefined): void {
  if (values === undefined) return;
  if (values.length) url.searchParams.set(key, values.join(','));
  else url.searchParams.delete(key);
}

export function debouncedUpdateFilterUrl(params: FilterUrlParams): void {
  if (filterTimer) clearTimeout(filterTimer);
  filterTimer = setTimeout(() => {
    const url = new URL(location.href);
    setListParam(url, 'river-state', params.riverStates);
    setListParam(url, 'basin', params.basins);
    if (params.drainageType !== undefined) {
      if (params.drainageType) url.searchParams.set('type', params.drainageType);
      else url.searchParams.delete('type');
    }
    if (params.transnational !== undefined) {
      if (params.transnational) url.searchParams.set('transnational', '1');
      else url.searchParams.delete('transnational');
    }
    setListParam(url, 'pa-categories', params.paCategories);
    setListParam(url, 'pa-state', params.paStates);
    history.replaceState(null, '', url);
  }, 300);
}

export function readInitialFilters(): {
  riverStates: string[];
  basins: string[];
  drainageType: string | null;
  transnational: boolean;
  paCategories: string[];
  paStates: string[];
} {
  const params = new URLSearchParams(location.search);
  const list = (key: string) => params.get(key)?.split(',').filter(Boolean) ?? [];
  return {
    riverStates: list('river-state'),
    basins: list('basin'),
    drainageType: params.get('type'),
    transnational: params.get('transnational') === '1',
    paCategories: list('pa-categories'),
    paStates: list('pa-state'),
  };
}
