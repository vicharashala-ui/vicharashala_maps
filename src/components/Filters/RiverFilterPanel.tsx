import { useStore } from '@nanostores/preact';
import {
  riverFilters,
  resetRiverFilters,
  hasActiveRiverFilters,
  riverFilterCount,
  type RiverFilters,
} from '../../utils/filterStore';
import { states, basins, getState, getBasin } from '../../utils/dataStore';
import { debouncedUpdateFilterUrl } from '../../utils/urlState';
import { DRAINAGE_LABEL } from '../Browse/RiverBrowseList';
import FilterChip from './FilterChip';
import type { RiverIndexEntry } from '../../utils/types';

const DRAINAGE_OPTIONS: RiverIndexEntry['drainage_type'][] = ['himalayan', 'peninsular', 'coastal', 'inland'];

function toggle(list: string[], value: string): string[] {
  return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
}

export default function RiverFilterPanel() {
  const filters = useStore(riverFilters);
  const active = hasActiveRiverFilters(filters);

  function update(patch: Partial<RiverFilters>) {
    const next = { ...filters, ...patch };
    riverFilters.set(next);
    debouncedUpdateFilterUrl({
      riverStates: next.states,
      basins: next.basins,
      drainageType: next.drainageType,
      transnational: next.transnational,
    });
  }

  function resetAll() {
    resetRiverFilters();
    debouncedUpdateFilterUrl({ riverStates: [], basins: [], drainageType: null, transnational: false });
  }

  return (
    <div className="border-b px-3 py-2 text-sm" style={{ borderColor: 'var(--color-border)' }}>
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-semibold uppercase tracking-wide" style={{ color: 'var(--color-text-muted)' }}>
          Filters
        </span>
        {active && (
          <button type="button" className="text-xs underline" style={{ color: 'var(--color-accent)' }} onClick={resetAll}>
            Reset all ({riverFilterCount(filters)})
          </button>
        )}
      </div>

      {active && (
        <div className="mb-1">
          {filters.states.map((id) => (
            <FilterChip
              key={`s-${id}`}
              label={getState(id)?.name ?? id}
              onRemove={() => update({ states: filters.states.filter((v) => v !== id) })}
            />
          ))}
          {filters.basins.map((id) => (
            <FilterChip
              key={`b-${id}`}
              label={getBasin(id)?.name ?? id}
              onRemove={() => update({ basins: filters.basins.filter((v) => v !== id) })}
            />
          ))}
          {filters.drainageType && (
            <FilterChip label={DRAINAGE_LABEL[filters.drainageType]} onRemove={() => update({ drainageType: null })} />
          )}
          {filters.transnational && <FilterChip label="Transnational" onRemove={() => update({ transnational: false })} />}
        </div>
      )}

      <details className="mt-1">
        <summary className="cursor-pointer text-xs">
          State/UT {filters.states.length > 0 && `(${filters.states.length})`}
        </summary>
        <div className="max-h-28 overflow-y-auto mt-1 flex flex-col gap-0.5 pl-1">
          {states.map((s) => (
            <label key={s.id} className="flex items-center gap-1.5 text-xs">
              <input
                type="checkbox"
                checked={filters.states.includes(s.id)}
                onChange={() => update({ states: toggle(filters.states, s.id) })}
              />
              {s.name}
            </label>
          ))}
        </div>
      </details>

      <details className="mt-1">
        <summary className="cursor-pointer text-xs">
          Basin {filters.basins.length > 0 && `(${filters.basins.length})`}
        </summary>
        <div className="max-h-28 overflow-y-auto mt-1 flex flex-col gap-0.5 pl-1">
          {basins.map((b) => (
            <label key={b.id} className="flex items-center gap-1.5 text-xs">
              <input
                type="checkbox"
                checked={filters.basins.includes(b.id)}
                onChange={() => update({ basins: toggle(filters.basins, b.id) })}
              />
              <span className="inline-block w-2 h-2 rounded-full shrink-0" style={{ background: b.color_light }} />
              {b.name}
            </label>
          ))}
        </div>
      </details>

      <div className="mt-1.5 flex items-center gap-2">
        <label className="text-xs" style={{ color: 'var(--color-text-muted)' }}>
          Drainage type
        </label>
        <select
          className="text-xs rounded border px-1 py-0.5 flex-1 min-w-0"
          style={{ borderColor: 'var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)' }}
          value={filters.drainageType ?? ''}
          onChange={(e) => update({ drainageType: (e.target as HTMLSelectElement).value as RiverFilters['drainageType'] || null })}
        >
          <option value="">All</option>
          {DRAINAGE_OPTIONS.map((d) => (
            <option key={d} value={d}>
              {DRAINAGE_LABEL[d]}
            </option>
          ))}
        </select>
      </div>

      <label className="mt-1.5 flex items-center gap-1.5 text-xs">
        <input
          type="checkbox"
          checked={filters.transnational}
          onChange={(e) => update({ transnational: (e.target as HTMLInputElement).checked })}
        />
        Transnational only
      </label>
    </div>
  );
}
