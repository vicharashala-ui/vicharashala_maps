import { useMemo } from 'preact/hooks';
import { useStore } from '@nanostores/preact';
import { riversIndex, getBasin } from '../../utils/dataStore';
import { selectRiver } from '../../utils/mapStore';
import { matchingRiverIds } from '../../utils/filterStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import { useWindowedList } from '../../utils/useWindowedList';
import type { RiverIndexEntry } from '../../utils/types';

const ROW_HEIGHT = 40;

type Row = { kind: 'header'; basinId: string; label: string } | { kind: 'river'; river: RiverIndexEntry };

export const DRAINAGE_LABEL: Record<RiverIndexEntry['drainage_type'], string> = {
  himalayan: 'Himalayan',
  peninsular: 'Peninsular',
  coastal: 'Coastal',
  inland: 'Inland',
};

function TransnationalIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" />
      <path d="M1.5 8h13M8 1.5c2 2 2 11 0 13M8 1.5c-2 2-2 11 0 13" strokeLinecap="round" />
    </svg>
  );
}

function buildRows(activeIds: Set<string> | null): Row[] {
  const source = activeIds ? riversIndex.filter((r) => activeIds.has(r.id)) : riversIndex;
  const byBasin = new Map<string, RiverIndexEntry[]>();
  for (const river of source) {
    if (!byBasin.has(river.basin)) byBasin.set(river.basin, []);
    byBasin.get(river.basin)!.push(river);
  }
  // Basin-grouped in the same area-rank order as basins.json, so the largest basins surface
  // first; a basin id absent from basins.json (shouldn't happen — validateBasins.js checks the
  // reverse direction) falls back to sorting after all ranked ones.
  const orderedBasinIds = [...byBasin.keys()].sort((a, b) => {
    const rankA = getBasin(a)?.area_rank ?? Number.MAX_SAFE_INTEGER;
    const rankB = getBasin(b)?.area_rank ?? Number.MAX_SAFE_INTEGER;
    return rankA - rankB;
  });

  const rows: Row[] = [];
  for (const basinId of orderedBasinIds) {
    rows.push({ kind: 'header', basinId, label: getBasin(basinId)?.name ?? basinId });
    const rivers = byBasin.get(basinId)!.slice().sort((a, b) => a.name.localeCompare(b.name));
    for (const river of rivers) rows.push({ kind: 'river', river });
  }
  return rows;
}

export default function RiverBrowseList() {
  const activeIds = useStore(matchingRiverIds);
  const rows = useMemo(() => buildRows(activeIds), [activeIds]);
  const { containerRef, startIndex, endIndex, totalHeight, offsetY } = useWindowedList(rows.length, ROW_HEIGHT);

  function pick(river: RiverIndexEntry) {
    selectRiver(river.id);
    debouncedUpdateUrl({ river: river.id });
  }

  if (rows.length === 0) {
    return (
      <div className="p-4 text-sm" style={{ color: 'var(--color-text-muted)' }}>
        No rivers match the current filters.
      </div>
    );
  }

  return (
    <div ref={containerRef} className="h-full overflow-y-auto" role="list" aria-label="Rivers, grouped by basin">
      <div style={{ height: totalHeight, position: 'relative' }}>
        <div style={{ transform: `translateY(${offsetY}px)` }}>
          {rows.slice(startIndex, endIndex).map((row) =>
            row.kind === 'header' ? (
              <div
                key={`h-${row.basinId}`}
                style={{ height: ROW_HEIGHT }}
                className="flex items-end px-3 pb-1 text-xs font-semibold uppercase tracking-wide"
              >
                <span style={{ color: 'var(--color-text-muted)' }}>{row.label}</span>
              </div>
            ) : (
              <button
                key={row.river.id}
                type="button"
                role="listitem"
                style={{ height: ROW_HEIGHT }}
                className="w-full flex items-center justify-between gap-2 px-3 text-sm text-left hover:opacity-80"
                onClick={() => pick(row.river)}
              >
                <span className="truncate">{row.river.name}</span>
                <span
                  className="flex items-center gap-2 shrink-0 text-xs"
                  style={{ color: 'var(--color-text-muted)' }}
                >
                  {row.river.transnational && <TransnationalIcon />}
                  <span>{DRAINAGE_LABEL[row.river.drainage_type]}</span>
                  <span>{row.river.length_km_india} km</span>
                </span>
              </button>
            ),
          )}
        </div>
      </div>
    </div>
  );
}
