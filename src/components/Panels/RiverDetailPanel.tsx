import { useStore } from '@nanostores/preact';
import { selectedRiverId, activePanel, closePanel, selectPA, selectState } from '../../utils/mapStore';
import { riversIndex, getBasin, getState, loadPAData, paDataLoaded } from '../../utils/dataStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import { isDarkTheme } from '../../utils/theme';
import { useEffect, useState } from 'preact/hooks';
import { useFocusOnOpen } from '../../utils/useFocusOnOpen';
import type { ComponentChildren } from 'preact';
import type { ProtectedArea } from '../../utils/types';

function Chip({ children, onClick }: { children: ComponentChildren; onClick?: () => void }) {
  const Tag = onClick ? 'button' : 'span';
  return (
    <Tag
      className="inline-block rounded-full px-2 py-0.5 text-xs mr-1 mb-1"
      style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)' }}
      onClick={onClick}
    >
      {children}
    </Tag>
  );
}

function BasinBadge({ basinId }: { basinId: string }) {
  const basin = getBasin(basinId);
  if (!basin) return <Chip>{basinId.replace(/-basin$/, '').replace(/-/g, ' ')}</Chip>;
  const color = isDarkTheme() ? basin.color_dark : basin.color_light;
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs mr-1 mb-1"
      style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)' }}
    >
      <span className="inline-block w-2 h-2 rounded-full" style={{ background: color }} aria-hidden="true" />
      {basin.name}
    </span>
  );
}

export default function RiverDetailPanel() {
  const riverId = useStore(selectedRiverId);
  const panel = useStore(activePanel);
  const [relatedPAs, setRelatedPAs] = useState<ProtectedArea[]>([]);
  const river = riverId ? riversIndex.find((r) => r.id === riverId) : undefined;
  const panelRef = useFocusOnOpen<HTMLElement>(panel === 'river' && !!river);

  useEffect(() => {
    if (!riverId) return;
    loadPAData().then(({ protectedAreas }) => {
      setRelatedPAs(protectedAreas.filter((pa) => pa.river_ids.includes(riverId)));
    });
  }, [riverId]);

  if (panel !== 'river' || !river) return null;

  return (
    <aside
      ref={panelRef}
      tabIndex={-1}
      className="panel-slide-in absolute top-0 right-0 h-full w-full sm:w-[360px] overflow-y-auto border-l shadow-lg z-20"
      style={{ background: 'var(--color-bg)', borderColor: 'var(--color-border)' }}
    >
      <div className="flex items-start justify-between p-4 border-b" style={{ borderColor: 'var(--color-border)' }}>
        <div>
          <h2 className="text-lg font-semibold" style={{ fontFamily: 'Sora, sans-serif' }}>
            {river.name}
          </h2>
          <p className="text-sm" style={{ color: 'var(--color-text-muted)' }}>
            {river.local_name_hi}
          </p>
          <BasinBadge basinId={river.basin} />
        </div>
        <button aria-label="Close" onClick={closePanel} className="text-xl leading-none px-2">
          ×
        </button>
      </div>

      <div className="p-4 flex flex-col gap-3 text-sm">
        <div className="grid grid-cols-2 gap-2">
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Length (India)</div>
            <div className="font-medium">{river.length_km_india} km</div>
          </div>
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Basin area (India)</div>
            <div className="font-medium">
              {river.basin_area_india_km2 ? `${river.basin_area_india_km2.toLocaleString()} km²` : '—'}
            </div>
          </div>
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Drainage type</div>
            <div className="font-medium capitalize">{river.drainage_type}</div>
          </div>
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Seasonal type</div>
            <div className="font-medium capitalize">{river.seasonal_type}</div>
          </div>
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Origin</div>
            <div className="font-medium capitalize">{river.origin_type.replace('-', ' ')}</div>
          </div>
          <div>
            <div style={{ color: 'var(--color-text-muted)' }}>Stream order</div>
            <div className="font-medium">{river.stream_order}</div>
          </div>
        </div>

        <div className="flex gap-2 flex-wrap">
          {river.navigable && <Chip>Navigable</Chip>}
          {river.transnational && <Chip>Transnational</Chip>}
        </div>

        <div>
          <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
            States
          </div>
          <div>
            {river.states.map((s) => (
              <Chip
                key={s}
                onClick={() => {
                  selectState(s);
                  debouncedUpdateUrl({ state: s });
                }}
              >
                {getState(s)?.name ?? s}
              </Chip>
            ))}
          </div>
        </div>

        {river.aliases.length > 0 && (
          <div>
            <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
              Also known as
            </div>
            <div>{river.aliases.join(', ')}</div>
          </div>
        )}

        <div>
          <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
            Associated Protected Areas
          </div>
          {!paDataLoaded.get() && relatedPAs.length === 0 && (
            <div style={{ color: 'var(--color-text-muted)' }}>Loading…</div>
          )}
          {paDataLoaded.get() && relatedPAs.length === 0 && (
            <div style={{ color: 'var(--color-text-muted)' }}>None recorded</div>
          )}
          <ul className="flex flex-col gap-1">
            {relatedPAs.map((pa) => (
              <li key={pa.id} className="flex items-center justify-between">
                <span>
                  {pa.name} <Chip>{pa.category.toUpperCase()}</Chip>
                </span>
                <button
                  className="text-xs underline"
                  style={{ color: 'var(--color-accent)' }}
                  onClick={() => {
                    selectPA(pa.id);
                    debouncedUpdateUrl({ pa: pa.id });
                  }}
                >
                  Show on map
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </aside>
  );
}
