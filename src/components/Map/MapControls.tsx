import { useStore } from '@nanostores/preact';
import { mapInstance, closePanel } from '../../utils/mapStore';
import { debouncedUpdateUrl } from '../../utils/urlState';

const INDIA_BOUNDS: [number, number, number, number] = [68.1, 6.4, 97.4, 37.1];

export default function MapControls() {
  const map = useStore(mapInstance);
  if (!map) return null;

  function reset() {
    map!.fitBounds(INDIA_BOUNDS, { duration: 400, padding: 20 });
    closePanel();
    debouncedUpdateUrl({});
  }

  return (
    <div className="absolute bottom-6 right-4 z-10 flex flex-col gap-1">
      <button
        type="button"
        aria-label="Zoom in"
        className="h-9 w-9 rounded border shadow-sm text-lg leading-none"
        style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)', color: 'var(--color-text)' }}
        onClick={() => map.zoomIn()}
      >
        +
      </button>
      <button
        type="button"
        aria-label="Zoom out"
        className="h-9 w-9 rounded border shadow-sm text-lg leading-none"
        style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)', color: 'var(--color-text)' }}
        onClick={() => map.zoomOut()}
      >
        −
      </button>
      <button
        type="button"
        aria-label="Reset view"
        className="h-9 w-9 rounded border shadow-sm flex items-center justify-center"
        style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)', color: 'var(--color-text)' }}
        onClick={reset}
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
          <path d="M2 6V2h4M14 6V2h-4M2 10v4h4M14 10v4h-4" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
    </div>
  );
}
