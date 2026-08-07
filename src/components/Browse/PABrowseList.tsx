import { useEffect, useMemo, useState } from 'preact/hooks';
import { useStore } from '@nanostores/preact';
import { loadPAData } from '../../utils/dataStore';
import { selectPA } from '../../utils/mapStore';
import { paFilters, paMatchesFilters } from '../../utils/filterStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import { useWindowedList } from '../../utils/useWindowedList';
import type { ProtectedArea } from '../../utils/types';

const ROW_HEIGHT = 44;

const CATEGORY_LABEL: Record<ProtectedArea['category'], string> = {
  np: 'NP',
  wls: 'WLS',
  tr: 'TR',
  br: 'BR',
  ramsar: 'Ramsar',
};

export default function PABrowseList() {
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>('loading');
  const [areas, setAreas] = useState<ProtectedArea[]>([]);

  function load() {
    setStatus('loading');
    loadPAData()
      .then(({ protectedAreas }) => {
        setAreas(protectedAreas.slice().sort((a, b) => a.name.localeCompare(b.name)));
        setStatus('ready');
      })
      .catch(() => setStatus('error'));
  }

  // Flat, not category-grouped (§3.7 allows either "category-grouped or flat (filter-driven)"
  // — filtered by the PA filter panel's Category/State selections below).
  useEffect(load, []);

  const filters = useStore(paFilters);
  const filtered = useMemo(() => areas.filter((pa) => paMatchesFilters(pa, filters)), [areas, filters]);
  const { containerRef, startIndex, endIndex, totalHeight, offsetY } = useWindowedList(filtered.length, ROW_HEIGHT);

  function pick(pa: ProtectedArea) {
    selectPA(pa.id);
    debouncedUpdateUrl({ pa: pa.id });
  }

  if (status === 'loading') {
    return (
      <div className="p-4 text-sm" style={{ color: 'var(--color-text-muted)' }}>
        Loading protected areas…
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="p-4 text-sm flex items-center justify-between">
        <span>Couldn&apos;t load protected areas.</span>
        <button type="button" className="underline" style={{ color: 'var(--color-accent)' }} onClick={load}>
          Retry
        </button>
      </div>
    );
  }

  if (filtered.length === 0) {
    return (
      <div className="p-4 text-sm" style={{ color: 'var(--color-text-muted)' }}>
        No protected areas match the current filters.
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className="h-full overflow-y-auto"
      role="list"
      aria-label="Protected areas"
    >
      <div style={{ height: totalHeight, position: 'relative' }}>
        <div style={{ transform: `translateY(${offsetY}px)` }}>
          {filtered.slice(startIndex, endIndex).map((pa) => (
            <button
              key={pa.id}
              type="button"
              role="listitem"
              style={{ height: ROW_HEIGHT }}
              className="w-full flex flex-col justify-center gap-0.5 px-3 text-sm text-left hover:opacity-80"
              onClick={() => pick(pa)}
            >
              <span className="flex items-center gap-2">
                <span
                  className="inline-block rounded px-1.5 py-0.5 text-[10px] font-semibold"
                  style={{ background: `var(--color-pa-${pa.category}-label)`, color: '#fff' }}
                >
                  {CATEGORY_LABEL[pa.category]}
                </span>
                <span className="truncate">{pa.name}</span>
              </span>
              <span className="text-xs truncate" style={{ color: 'var(--color-text-muted)' }}>
                {pa.state.join(', ')} · {pa.area_km2 > 0 ? `${pa.area_km2} km²` : 'Area not recorded'}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
