import { useStore } from '@nanostores/preact';
import { paLayerVisible, paLayerCategories, stateBordersVisible } from '../../utils/mapStore';

const PA_CATEGORIES: { id: string; label: string }[] = [
  { id: 'np', label: 'National Parks' },
  { id: 'wls', label: 'Wildlife Sanctuaries' },
  { id: 'tr', label: 'Tiger Reserves' },
  { id: 'br', label: 'Biosphere Reserves' },
  { id: 'ramsar', label: 'Ramsar Sites' },
];

export default function LayerControl() {
  const visible = useStore(paLayerVisible);
  const categories = useStore(paLayerCategories);
  const bordersVisible = useStore(stateBordersVisible);

  function toggleCategory(id: string) {
    const next = new Set(categories);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    paLayerCategories.set(next);
  }

  return (
    <div
      className="absolute top-4 right-4 z-10 w-56 rounded-lg border shadow-sm"
      style={{ background: 'var(--color-surface)', borderColor: 'var(--color-border)' }}
    >
      <div className="px-3 py-2 border-b text-sm font-semibold" style={{ borderColor: 'var(--color-border)' }}>
        Layers
      </div>
      <div className="px-3 py-2 border-b text-sm" style={{ borderColor: 'var(--color-border)' }}>
        <label className="flex items-center gap-2">
          <input type="checkbox" checked readOnly disabled />
          Rivers
        </label>
      </div>
      <div className="px-3 py-2 border-b text-sm" style={{ borderColor: 'var(--color-border)' }}>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={bordersVisible}
            onChange={(e) => stateBordersVisible.set((e.target as HTMLInputElement).checked)}
          />
          State Borders
        </label>
      </div>
      <div className="px-3 py-2 text-sm">
        <label className="flex items-center gap-2 font-medium">
          <input
            type="checkbox"
            checked={visible}
            onChange={(e) => paLayerVisible.set((e.target as HTMLInputElement).checked)}
          />
          Protected Areas
        </label>
        {visible && (
          <div className="mt-2 ml-6 flex flex-col gap-1">
            {PA_CATEGORIES.map((cat) => (
              <label key={cat.id} className="flex items-center gap-2 text-xs" style={{ color: 'var(--color-text-muted)' }}>
                <input type="checkbox" checked={categories.has(cat.id)} onChange={() => toggleCategory(cat.id)} />
                {cat.label}
              </label>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
