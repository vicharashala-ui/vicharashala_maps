// Shared close control for panels (River/PA/State detail, Browse) — replaces the bare "×" text
// glyph each panel used to render inline, so hit target/hover/focus behave identically everywhere.
export default function CloseButton({ onClick, label = 'Close' }: { onClick: () => void; label?: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="icon-btn h-8 w-8 rounded-full flex items-center justify-center shrink-0"
      style={{ color: 'var(--color-text-muted)' }}
    >
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden="true">
        <path d="M4 4l8 8M12 4l-8 8" strokeLinecap="round" />
      </svg>
    </button>
  );
}
