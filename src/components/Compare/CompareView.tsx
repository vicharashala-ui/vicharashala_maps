import { useEffect, useState } from 'preact/hooks';
import { riversIndex, getState, loadRiverDetail } from '../../utils/dataStore';
import { updateCompareUrl, readInitialCompareRivers } from '../../utils/urlState';
import type { RiverDetail, RiverIndexEntry } from '../../utils/types';

type DetailState = { status: 'loading' } | { status: 'error' } | { status: 'loaded'; detail: RiverDetail };

const MAX_RIVERS = 3;
const sortedRivers = [...riversIndex].sort((a, b) => a.name.localeCompare(b.name));

function formatTributaries(detail: RiverDetail): string {
  const names = [...detail.tributaries.left, ...detail.tributaries.right];
  if (names.length === 0) return 'None recorded';
  return names.map((id) => sortedRivers.find((r) => r.id === id)?.name ?? id).join(', ');
}

export default function CompareView() {
  // Starts empty (not read from URL) since this component is prerendered on the server, where
  // `location` doesn't exist — the real initial selection is hydrated in the effect below.
  const [riverIds, setRiverIds] = useState<(string | null)[]>([null, null, null]);
  const [details, setDetails] = useState<Record<string, DetailState>>({});
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const initial = readInitialCompareRivers();
    setRiverIds([initial[0] ?? null, initial[1] ?? null, initial[2] ?? null]);
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return; // avoid clobbering the URL with [null,null,null] before hydration runs
    updateCompareUrl(riverIds);
    for (const id of riverIds) {
      if (!id || details[id]) continue;
      setDetails((prev) => ({ ...prev, [id]: { status: 'loading' } }));
      loadRiverDetail(id)
        .then((detail) => setDetails((prev) => ({ ...prev, [id]: { status: 'loaded', detail } })))
        .catch(() => setDetails((prev) => ({ ...prev, [id]: { status: 'error' } })));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- `details` intentionally excluded, would refetch on every load
  }, [riverIds, hydrated]);

  const selected = riverIds.filter((id): id is string => !!id);
  const canAddMore = selected.length < MAX_RIVERS;

  function setSlot(index: number, id: string | null): void {
    setRiverIds((prev) => {
      const next = [...prev];
      next[index] = id;
      return next;
    });
  }

  function retryDetail(id: string): void {
    setDetails((prev) => ({ ...prev, [id]: { status: 'loading' } }));
    loadRiverDetail(id)
      .then((detail) => setDetails((prev) => ({ ...prev, [id]: { status: 'loaded', detail } })))
      .catch(() => setDetails((prev) => ({ ...prev, [id]: { status: 'error' } })));
  }

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6">
      <a href="/" className="text-sm underline" style={{ color: 'var(--color-accent)' }}>
        ← Back to map
      </a>
      <h1 className="text-2xl font-semibold mt-2 mb-1" style={{ fontFamily: 'Sora, sans-serif' }}>
        Compare Rivers
      </h1>
      <p className="text-sm mb-6" style={{ color: 'var(--color-text-muted)' }}>
        Select 2–3 rivers to compare side by side.
      </p>

      <div className="flex flex-wrap gap-2 mb-6">
        {riverIds.map((id, i) => {
          if (id) {
            const river = riversIndex.find((r) => r.id === id);
            return (
              <span
                key={i}
                className="inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-sm"
                style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)' }}
              >
                {river?.name ?? id}
                <button
                  aria-label={`Remove ${river?.name ?? id} from comparison`}
                  onClick={() => setSlot(i, null)}
                  className="leading-none"
                >
                  ×
                </button>
              </span>
            );
          }
          if (!canAddMore && selected.length > 0) return null;
          return (
            <select
              key={i}
              aria-label="Add a river to compare"
              className="rounded-full px-3 py-1.5 text-sm"
              style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)', color: 'var(--color-text)' }}
              value=""
              onChange={(e) => setSlot(i, (e.target as HTMLSelectElement).value || null)}
            >
              <option value="">+ Add river…</option>
              {sortedRivers
                .filter((r) => !selected.includes(r.id))
                .map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name}
                  </option>
                ))}
            </select>
          );
        })}
      </div>

      {selected.length < 2 ? (
        <p style={{ color: 'var(--color-text-muted)' }}>Select at least 2 rivers to see a comparison.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm border-collapse">
            <thead>
              <tr>
                <th className="text-left p-2 border-b" style={{ borderColor: 'var(--color-border)' }} />
                {selected.map((id) => {
                  const river = riversIndex.find((r) => r.id === id);
                  return (
                    <th
                      key={id}
                      className="text-left p-2 border-b font-semibold"
                      style={{ borderColor: 'var(--color-border)', fontFamily: 'Sora, sans-serif' }}
                    >
                      {river?.name ?? id}
                    </th>
                  );
                })}
              </tr>
            </thead>
            <tbody>
              <CompareRow label="Length (India)" ids={selected} render={(river) => `${river.length_km_india} km`} />
              <CompareRow
                label="Total Length"
                ids={selected}
                renderDetail={details}
                render={(_river, detail) => (detail ? `${detail.length_km_total} km` : undefined)}
              />
              <CompareRow
                label="Basin Area (India)"
                ids={selected}
                render={(river) => (river.basin_area_india_km2 ? `${river.basin_area_india_km2.toLocaleString()} km²` : '—')}
              />
              <CompareRow label="Drainage Type" ids={selected} render={(river) => capitalize(river.drainage_type)} />
              <CompareRow label="Seasonal Type" ids={selected} render={(river) => capitalize(river.seasonal_type)} />
              <CompareRow
                label="States"
                ids={selected}
                render={(river) => river.states.map((s) => getState(s)?.name ?? s).join(', ')}
              />
              <CompareRow
                label="Tributaries"
                ids={selected}
                renderDetail={details}
                render={(_river, detail) => (detail ? formatTributaries(detail) : undefined)}
              />
              <CompareRow label="Navigable" ids={selected} render={(river) => (river.navigable ? 'Yes' : 'No')} />
              <CompareRow
                label="Flows into"
                ids={selected}
                renderDetail={details}
                render={(_river, detail) => (detail ? detail.sink.name : undefined)}
              />
            </tbody>
          </table>
          {selected
            .filter((id) => details[id]?.status === 'error')
            .map((id) => (
              <p key={id} className="text-sm mt-2" style={{ color: 'var(--color-text-muted)' }}>
                Couldn't load details for {riversIndex.find((r) => r.id === id)?.name ?? id}.{' '}
                <button className="underline" style={{ color: 'var(--color-accent)' }} onClick={() => retryDetail(id)}>
                  Retry
                </button>
              </p>
            ))}
        </div>
      )}
    </div>
  );
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1).replace('-', ' ');
}

function CompareRow({
  label,
  ids,
  render,
  renderDetail,
}: {
  label: string;
  ids: string[];
  render: (river: RiverIndexEntry, detail?: RiverDetail) => string | undefined;
  renderDetail?: Record<string, DetailState>;
}) {
  return (
    <tr>
      <th
        className="text-left p-2 border-b font-normal align-top"
        style={{ borderColor: 'var(--color-border)', color: 'var(--color-text-muted)' }}
      >
        {label}
      </th>
      {ids.map((id) => {
        const river = riversIndex.find((r) => r.id === id);
        if (!river) return <td key={id} className="p-2 border-b" style={{ borderColor: 'var(--color-border)' }} />;
        const state = renderDetail?.[id];
        let value: string | undefined;
        if (renderDetail) {
          if (!state || state.status === 'loading') value = undefined;
          else if (state.status === 'error') value = '—';
          else value = render(river, state.detail);
        } else {
          value = render(river);
        }
        return (
          <td key={id} className="p-2 border-b align-top" style={{ borderColor: 'var(--color-border)' }}>
            {value ?? <span style={{ color: 'var(--color-text-muted)' }}>Loading…</span>}
          </td>
        );
      })}
    </tr>
  );
}
