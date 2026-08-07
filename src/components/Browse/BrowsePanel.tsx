import { useStore } from '@nanostores/preact';
import { browseOpen, browseTab } from '../../utils/mapStore';
import { useFocusOnOpen } from '../../utils/useFocusOnOpen';
import RiverBrowseList from './RiverBrowseList';
import PABrowseList from './PABrowseList';

// Toggle button lives here (not MapControls) so Browse mode stays a single self-contained
// island — the primary keyboard-accessible route to feature selection (§12), since MapLibre's
// KeyboardHandler only supports pan/zoom, not feature selection, via keyboard.
export default function BrowsePanel() {
  const open = useStore(browseOpen);
  const tab = useStore(browseTab);
  const panelRef = useFocusOnOpen<HTMLElement>(open);

  return (
    <>
      <button
        type="button"
        aria-expanded={open}
        aria-controls="browse-panel"
        className="absolute bottom-6 left-4 z-10 h-9 px-3 rounded border shadow-sm text-sm font-medium flex items-center gap-2"
        style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)', color: 'var(--color-text)' }}
        onClick={() => browseOpen.set(!open)}
      >
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden="true">
          <path d="M2 4h12M2 8h12M2 12h8" strokeLinecap="round" />
        </svg>
        Browse
      </button>

      {open && (
        <aside
          id="browse-panel"
          ref={panelRef}
          tabIndex={-1}
          className="panel-slide-in absolute top-0 left-0 h-full w-full sm:w-[280px] flex flex-col border-r shadow-lg z-20"
          style={{ background: 'var(--color-bg)', borderColor: 'var(--color-border)' }}
        >
          <div className="flex items-center justify-between p-3 border-b" style={{ borderColor: 'var(--color-border)' }}>
            <div role="tablist" aria-label="Browse" className="flex gap-1">
              <TabButton active={tab === 'rivers'} onClick={() => browseTab.set('rivers')}>
                Rivers
              </TabButton>
              <TabButton active={tab === 'pa'} onClick={() => browseTab.set('pa')}>
                Protected Areas
              </TabButton>
            </div>
            <button aria-label="Close" onClick={() => browseOpen.set(false)} className="text-xl leading-none px-2">
              ×
            </button>
          </div>

          <div className="flex-1 min-h-0">
            {tab === 'rivers' ? <RiverBrowseList /> : <PABrowseList />}
          </div>
        </aside>
      )}
    </>
  );
}

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: string }) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      className="px-2 py-1 rounded text-sm font-medium"
      style={{
        background: active ? 'var(--color-accent)' : 'transparent',
        color: active ? '#fff' : 'var(--color-text)',
      }}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
