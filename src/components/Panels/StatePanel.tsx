import { useStore } from '@nanostores/preact';
import { useEffect, useState } from 'preact/hooks';
import { useFocusOnOpen } from '../../utils/useFocusOnOpen';
import { selectedStateId, activePanel, closePanel, selectRiver, selectPA } from '../../utils/mapStore';
import { getState, getCity, riversIndex, loadPAData, paDataLoaded } from '../../utils/dataStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import CloseButton from '../UI/CloseButton';
import type { ProtectedArea } from '../../utils/types';

export default function StatePanel() {
  const stateId = useStore(selectedStateId);
  const panel = useStore(activePanel);
  const [relatedPAs, setRelatedPAs] = useState<ProtectedArea[]>([]);
  const state = stateId ? getState(stateId) : undefined;
  const panelRef = useFocusOnOpen<HTMLElement>(panel === 'state' && !!state);

  useEffect(() => {
    if (!state?.protected_area_ids.length) {
      setRelatedPAs([]);
      return;
    }
    loadPAData().then(({ protectedAreas }) => {
      setRelatedPAs(protectedAreas.filter((pa) => state.protected_area_ids.includes(pa.id)));
    });
  }, [state]);

  if (panel !== 'state' || !state) return null;

  const rivers = state.rivers_flowing_through
    .map((id) => riversIndex.find((r) => r.id === id))
    .filter(Boolean) as typeof riversIndex;
  const cities = state.notable_city_ids.map((id) => getCity(id)).filter(Boolean) as ReturnType<typeof getCity>[];
  const paNeedsLoad = state.protected_area_ids.length > 0 && !paDataLoaded.get() && relatedPAs.length === 0;

  return (
    <aside
      ref={panelRef}
      tabIndex={-1}
      className="panel-slide-in absolute top-0 right-0 h-full w-full sm:w-[360px] overflow-y-auto border-l shadow-lg z-20"
      style={{ background: 'var(--color-bg)', borderColor: 'var(--color-border)' }}
    >
      <div className="flex items-start justify-between p-4 border-b" style={{ borderColor: 'var(--color-border)' }}>
        <div>
          <span
            className="inline-block rounded px-2 py-0.5 text-xs font-medium mb-1"
            style={{ background: 'var(--color-accent)', color: '#fff' }}
          >
            {state.admin_type === 'ut' ? 'Union Territory' : 'State'}
          </span>
          <h2 className="text-lg font-semibold" style={{ fontFamily: 'Sora, sans-serif' }}>
            {state.name}
          </h2>
          <p className="text-sm" style={{ color: 'var(--color-text-muted)' }}>
            Capital: {state.capital}
          </p>
        </div>
        <CloseButton onClick={closePanel} />
      </div>

      <div className="p-4 flex flex-col gap-3 text-sm">
        <div>
          <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
            Rivers flowing through
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

        <div>
          <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
            Associated Protected Areas
          </div>
          {paNeedsLoad && <div style={{ color: 'var(--color-text-muted)' }}>Loading…</div>}
          {!paNeedsLoad && relatedPAs.length === 0 && (
            <div style={{ color: 'var(--color-text-muted)' }}>None recorded</div>
          )}
          <ul className="flex flex-col gap-1">
            {relatedPAs.map((pa) => (
              <li key={pa.id} className="flex items-center justify-between">
                <span>{pa.name}</span>
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

        {cities.length > 0 && (
          <div>
            <div style={{ color: 'var(--color-text-muted)' }} className="mb-1">
              Notable cities
            </div>
            <div>
              {cities.map((c) => (
                <span
                  key={c!.id}
                  className="inline-block rounded-full px-2 py-0.5 text-xs mr-1 mb-1"
                  style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)' }}
                >
                  {c!.name}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>
    </aside>
  );
}
