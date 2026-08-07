import { useStore } from '@nanostores/preact';
import { paFilters, resetPAFilters, hasActivePAFilters, paFilterCount, type PAFilters } from '../../utils/filterStore';
import { states } from '../../utils/dataStore';
import { debouncedUpdateFilterUrl } from '../../utils/urlState';
import FilterChip from './FilterChip';
import type { ProtectedArea } from '../../utils/types';

const CATEGORY_OPTIONS: { value: ProtectedArea['category']; label: string }[] = [
  { value: 'np', label: 'National Parks' },
  { value: 'wls', label: 'Wildlife Sanctuaries' },
  { value: 'tr', label: 'Tiger Reserves' },
  { value: 'br', label: 'Biosphere Reserves' },
  { value: 'ramsar', label: 'Ramsar Sites' },
];

function toggle<T>(list: T[], value: T): T[] {
  return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
}

export default function PAFilterPanel() {
  const filters = useStore(paFilters);
  const active = hasActivePAFilters(filters);

  function update(patch: Partial<PAFilters>) {
    const next = { ...filters, ...patch };
    paFilters.set(next);
    debouncedUpdateFilterUrl({ paCategories: next.categories, paStates: next.states });
  }

  function resetAll() {
    resetPAFilters();
    debouncedUpdateFilterUrl({ paCategories: [], paStates: [] });
  }

  return (
    <div className="border-b px-3 py-2 text-sm" style={{ borderColor: 'var(--color-border)' }}>
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-semibold uppercase tracking-wide" style={{ color: 'var(--color-text-muted)' }}>
          Filters
        </span>
        {active && (
          <button type="button" className="text-xs underline" style={{ color: 'var(--color-accent)' }} onClick={resetAll}>
            Reset all ({paFilterCount(filters)})
          </button>
        )}
      </div>

      {active && (
        <div className="mb-1">
          {filters.categories.map((c) => (
            <FilterChip
              key={`c-${c}`}
              label={CATEGORY_OPTIONS.find((o) => o.value === c)?.label ?? c}
              onRemove={() => update({ categories: filters.categories.filter((v) => v !== c) })}
            />
          ))}
          {filters.states.map((s) => (
            <FilterChip key={`s-${s}`} label={s} onRemove={() => update({ states: filters.states.filter((v) => v !== s) })} />
          ))}
        </div>
      )}

      <details className="mt-1" open>
        <summary className="cursor-pointer text-xs">
          Category {filters.categories.length > 0 && `(${filters.categories.length})`}
        </summary>
        <div className="mt-1 flex flex-col gap-0.5 pl-1">
          {CATEGORY_OPTIONS.map((o) => (
            <label key={o.value} className="flex items-center gap-1.5 text-xs">
              <input
                type="checkbox"
                checked={filters.categories.includes(o.value)}
                onChange={() => update({ categories: toggle(filters.categories, o.value) })}
              />
              {o.label}
            </label>
          ))}
        </div>
      </details>

      <details className="mt-1">
        <summary className="cursor-pointer text-xs">
          State/UT {filters.states.length > 0 && `(${filters.states.length})`}
        </summary>
        {/* ProtectedArea.state carries Title Case display names (not id slugs, unlike rivers/states
            data elsewhere) — matched by name here since that's the only form the PA dataset has. */}
        <div className="max-h-28 overflow-y-auto mt-1 flex flex-col gap-0.5 pl-1">
          {states.map((s) => (
            <label key={s.id} className="flex items-center gap-1.5 text-xs">
              <input
                type="checkbox"
                checked={filters.states.includes(s.name)}
                onChange={() => update({ states: toggle(filters.states, s.name) })}
              />
              {s.name}
            </label>
          ))}
        </div>
      </details>
    </div>
  );
}
