export default function FilterChip({ label, onRemove }: { label: string; onRemove: () => void }) {
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs mr-1 mb-1"
      style={{ background: 'var(--color-accent)', color: '#fff' }}
    >
      {label}
      <button type="button" aria-label={`Remove ${label} filter`} onClick={onRemove} className="leading-none">
        ×
      </button>
    </span>
  );
}
