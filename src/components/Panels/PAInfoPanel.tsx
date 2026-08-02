import { useStore } from '@nanostores/preact';
import { useEffect, useState } from 'preact/hooks';
import { selectedPAId, activePanel, closePanel, selectRiver } from '../../utils/mapStore';
import { loadPAData } from '../../utils/dataStore';
import { riversIndex } from '../../utils/dataStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import type { ProtectedArea } from '../../utils/types';

const CATEGORY_LABEL: Record<ProtectedArea['category'], string> = {
  np: 'National Park',
  wls: 'Wildlife Sanctuary',
  tr: 'Tiger Reserve',
  br: 'Biosphere Reserve',
  ramsar: 'Ramsar Site',
};

export default function PAInfoPanel() {
  const paId = useStore(selectedPAId);
  const panel = useStore(activePanel);
  const [pa, setPA] = useState<ProtectedArea | null>(null);

  useEffect(() => {
    if (!paId) {
      setPA(null);
      return;
    }
    loadPAData().then(({ protectedAreas }) => {
      setPA(protectedAreas.find((p) => p.id === paId) ?? null);
    });
  }, [paId]);

  if (panel !== 'pa' || !paId || !pa) return null;

  const rivers = pa.river_ids.map((id) => riversIndex.find((r) => r.id === id)).filter(Boolean) as typeof riversIndex;

  return (
    <aside
      className="panel-slide-in absolute top-0 right-0 h-full w-full sm:w-[360px] overflow-y-auto border-l shadow-lg z-20"
      style={{ background: 'var(--color-bg)', borderColor: 'var(--color-border)' }}
    >
      <div className="flex items-start justify-between p-4 border-b" style={{ borderColor: 'var(--color-border)' }}>
        <div>
          <span
            className="inline-block rounded px-2 py-0.5 text-xs font-medium mb-1"
            style={{ background: `var(--color-pa-${pa.category}-label)`, color: '#fff' }}
          >
            {CATEGORY_LABEL[pa.category]}
          </span>
          <h2 className="text-lg font-semibold" style={{ fontFamily: 'Sora, sans-serif' }}>
            {pa.name}
          </h2>
          <p className="text-sm" style={{ color: 'var(--color-text-muted)' }}>
            {pa.state.join(', ')}
          </p>
        </div>
        <button aria-label="Close" onClick={closePanel} className="text-xl leading-none px-2">
          ×
        </button>
      </div>

      <div className="p-4 flex flex-col gap-3 text-sm">
        <div>
          <div style={{ color: 'var(--color-text-muted)' }}>Area</div>
          <div className="font-medium">{pa.area_km2 > 0 ? `${pa.area_km2} km²` : 'Not recorded'}</div>
        </div>

        {pa.year_established && (
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Established</div>
            <div className="font-medium">{pa.year_established}</div>
          </div>
        )}

        {!pa.has_boundary && (
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Location</div>
            <div className="font-medium">
              {pa.centroid_lat.toFixed(4)}, {pa.centroid_lng.toFixed(4)}
            </div>
            <div className="text-xs mt-1" style={{ color: 'var(--color-text-muted)' }}>
              No mapped boundary — shown as a marker.
            </div>
          </div>
        )}

        <div>
          <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
            Associated Rivers
          </div>
          {rivers.length === 0 && <div style={{ color: 'var(--color-text-muted)' }}>None recorded</div>}
          <ul className="flex flex-col gap-1">
            {rivers.map((r) => (
              <li key={r.id} className="flex items-center justify-between">
                <span>{r.name}</span>
                <button
                  className="text-xs underline"
                  style={{ color: 'var(--color-accent)' }}
                  onClick={() => {
                    selectRiver(r.id);
                    debouncedUpdateUrl({ river: r.id });
                  }}
                >
                  Show on map
                </button>
              </li>
            ))}
          </ul>
        </div>

        {pa.wikipedia_url && (
          <a
            href={pa.wikipedia_url}
            target="_blank"
            rel="noopener noreferrer"
            className="underline"
            style={{ color: 'var(--color-accent)' }}
          >
            Open Wikipedia →
          </a>
        )}
      </div>
    </aside>
  );
}
