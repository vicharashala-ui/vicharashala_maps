import { useEffect, useRef } from 'preact/hooks';
import type { RefObject } from 'preact';

// Without this, a screen-reader user's focus stays on the row/control that triggered a
// selection while the panel's content renders elsewhere (§12). `isOpen` must match exactly
// whether the panel is actually in the DOM this render, since the ref only attaches when it is.
export function useFocusOnOpen<T extends HTMLElement>(isOpen: boolean): RefObject<T> {
  const ref = useRef<T>(null);
  const previouslyFocused = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previouslyFocused.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      ref.current?.focus();
    } else {
      previouslyFocused.current?.focus();
      previouslyFocused.current = null;
    }
  }, [isOpen]);

  return ref;
}
