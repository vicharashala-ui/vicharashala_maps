import { useEffect, useRef, useState } from 'preact/hooks';
import { useStore } from '@nanostores/preact';
import Fuse from 'fuse.js';
import { loadSearchIndex, loadPAData, paDataLoaded, type SearchIndexFile } from '../../utils/dataStore';
import { selectRiver, selectPA, selectState } from '../../utils/mapStore';
import { debouncedUpdateUrl } from '../../utils/urlState';
import type { SearchDoc, SearchRiverDoc, SearchStateDoc, SearchPADoc } from '../../utils/types';

const DEBOUNCE_MS = 150;

function buildFuse(indexFile: SearchIndexFile): Fuse<SearchDoc> {
  const parsedIndex = Fuse.parseIndex(indexFile.index as Parameters<typeof Fuse.parseIndex>[0]);
  const docs = indexFile.docs as unknown as SearchDoc[];
  return new Fuse(docs, { keys: indexFile.keys as never }, parsedIndex) as Fuse<SearchDoc>;
}

export default function SearchBar() {
  const inputRef = useRef<HTMLInputElement>(null);
  const primaryFuseRef = useRef<Fuse<SearchDoc> | null>(null);
  const paFuseRef = useRef<Fuse<SearchDoc> | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const paLoaded = useStore(paDataLoaded);

  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchDoc[]>([]);
  const [open, setOpen] = useState(false);
  const [status, setStatus] = useState<'idle' | 'loading' | 'error'>('idle');

  // Primary index (rivers + states) fetched once on first focus, not on mount — search is
  // usable from `client:idle` but shouldn't compete with first-paint network requests (§10.17).
  function ensurePrimaryIndex() {
    if (primaryFuseRef.current || status === 'loading') return;
    setStatus('loading');
    loadSearchIndex()
      .then((file) => {
        primaryFuseRef.current = buildFuse(file);
        setStatus('idle');
      })
      .catch(() => setStatus('error'));
  }

  // PA index only becomes searchable once loadPAData() has resolved elsewhere (layer toggle,
  // ?pa= deep link) — search itself never force-triggers it (§3.8).
  useEffect(() => {
    if (!paLoaded || paFuseRef.current) return;
    loadPAData().then(({ searchIndexPA }) => {
      paFuseRef.current = buildFuse(searchIndexPA);
      if (query) runSearch(query);
    });
  }, [paLoaded]);

  function runSearch(q: string) {
    const trimmed = q.trim();
    if (!trimmed || !primaryFuseRef.current) {
      setResults([]);
      return;
    }
    const primary = primaryFuseRef.current.search(trimmed).map((r) => r.item);
    const pa = paFuseRef.current?.search(trimmed).map((r) => r.item) ?? [];
    setResults([...primary, ...pa]);
  }

  function onInput(value: string) {
    setQuery(value);
    setOpen(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => runSearch(value), DEBOUNCE_MS);
  }

  function pick(doc: SearchDoc) {
    if (doc.type === 'river') {
      selectRiver(doc.id);
      debouncedUpdateUrl({ river: doc.id });
    } else if (doc.type === 'pa') {
      selectPA(doc.id);
      debouncedUpdateUrl({ pa: doc.id });
    } else {
      selectState(doc.id);
      debouncedUpdateUrl({ state: doc.id });
    }
    setQuery('');
    setResults([]);
    setOpen(false);
  }

  function onKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      setQuery('');
      setResults([]);
      setOpen(false);
      inputRef.current?.blur();
    }
  }

  // `/` focuses search from anywhere, unless already typing in a field (§3.8).
  useEffect(() => {
    function onGlobalKeyDown(e: KeyboardEvent) {
      if (e.key !== '/') return;
      const target = e.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable) return;
      e.preventDefault();
      ensurePrimaryIndex();
      inputRef.current?.focus();
    }
    window.addEventListener('keydown', onGlobalKeyDown);
    return () => window.removeEventListener('keydown', onGlobalKeyDown);
  }, []);

  const rivers = results.filter((d): d is SearchRiverDoc => d.type === 'river');
  const pas = results.filter((d): d is SearchPADoc => d.type === 'pa');
  const states = results.filter((d): d is SearchStateDoc => d.type === 'state');

  const statusText =
    status === 'error'
      ? ''
      : query.trim() && results.length === 0
        ? `No results for "${query.trim()}"`
        : results.length > 0
          ? `${results.length} result${results.length === 1 ? '' : 's'}`
          : '';

  return (
    <div className="absolute top-4 left-4 z-10 w-72 sm:w-80">
      <div
        className="rounded-lg border shadow-sm"
        style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)' }}
      >
        <input
          ref={inputRef}
          type="text"
          role="combobox"
          aria-expanded={open && (results.length > 0 || status !== 'idle')}
          aria-controls="search-results"
          aria-label="Search rivers, protected areas, and states"
          placeholder="Search rivers, parks, states… (/)"
          className="w-full px-3 py-2 text-sm bg-transparent outline-none"
          style={{ color: 'var(--color-text)' }}
          value={query}
          onFocus={ensurePrimaryIndex}
          onInput={(e) => onInput((e.target as HTMLInputElement).value)}
          onKeyDown={onKeyDown}
        />

        {status === 'error' && (
          <div
            className="px-3 py-2 text-sm border-t flex items-center justify-between"
            style={{ borderColor: 'var(--color-border)' }}
          >
            <span>Search unavailable.</span>
            <button type="button" className="underline" onClick={ensurePrimaryIndex}>
              Retry
            </button>
          </div>
        )}

        {open && query.trim() && status === 'idle' && (
          <div
            id="search-results"
            role="listbox"
            className="border-t max-h-96 overflow-y-auto"
            style={{ borderColor: 'var(--color-border)' }}
          >
            {results.length === 0 ? (
              <div
                className="px-3 py-2 text-sm flex items-center justify-between"
                style={{ color: 'var(--color-text-muted)' }}
              >
                <span>No results for &quot;{query.trim()}&quot;</span>
                <button type="button" className="underline" onClick={() => onInput('')}>
                  Clear
                </button>
              </div>
            ) : (
              <>
                <ResultGroup label="Rivers" docs={rivers} onPick={pick} render={(d) => `${d.name} · ${d.length_km_india} km`} />
                <ResultGroup
                  label="Protected Areas"
                  docs={pas}
                  onPick={pick}
                  render={(d) => `${d.name} · ${d.category.toUpperCase()}`}
                />
                <ResultGroup label="States" docs={states} onPick={pick} render={(d) => `${d.name} · ${d.capital}`} />
              </>
            )}
          </div>
        )}
      </div>

      <span className="sr-only" role="status" aria-live="polite">
        {statusText}
      </span>
    </div>
  );
}

function ResultGroup<T extends SearchDoc>({
  label,
  docs,
  onPick,
  render,
}: {
  label: string;
  docs: T[];
  onPick: (doc: T) => void;
  render: (doc: T) => string;
}) {
  if (docs.length === 0) return null;
  return (
    <div>
      <div
        className="px-3 pt-2 pb-1 text-xs font-semibold uppercase tracking-wide"
        style={{ color: 'var(--color-text-muted)' }}
      >
        {label}
      </div>
      {docs.map((doc) => (
        <button
          key={doc.id}
          type="button"
          role="option"
          aria-selected="false"
          className="w-full text-left px-3 py-2 text-sm hover:opacity-80"
          onClick={() => onPick(doc)}
        >
          {render(doc)}
        </button>
      ))}
    </div>
  );
}
