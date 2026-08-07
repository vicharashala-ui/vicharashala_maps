import { useEffect, useRef, useState } from 'preact/hooks';
import type { RefObject } from 'preact';

export interface WindowedList {
  containerRef: RefObject<HTMLDivElement>;
  startIndex: number;
  endIndex: number; // exclusive
  totalHeight: number;
  offsetY: number;
}

// Fixed-row-height virtualization: renders only the rows within the scrolled viewport (+
// overscan) inside a `totalHeight`-tall spacer, so a ~840-row PA list never mounts more than
// ~20 DOM rows at once. All rows (group headers included) share `rowHeight` — callers that
// need distinct header/item heights should render the shorter row at the same height rather
// than reach for variable-height offsets, to keep this simple (§4.9 sizes: rivers ~105, PAs 839).
export function useWindowedList(itemCount: number, rowHeight: number, overscan = 6): WindowedList {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = useState(0);
  const [viewportHeight, setViewportHeight] = useState(0);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    setViewportHeight(el.clientHeight);
    const onScroll = () => setScrollTop(el.scrollTop);
    el.addEventListener('scroll', onScroll, { passive: true });
    const ro = new ResizeObserver(() => setViewportHeight(el.clientHeight));
    ro.observe(el);
    return () => {
      el.removeEventListener('scroll', onScroll);
      ro.disconnect();
    };
  }, []);

  const startIndex = Math.max(0, Math.floor(scrollTop / rowHeight) - overscan);
  const visibleCount = Math.ceil(viewportHeight / rowHeight) + overscan * 2;
  const endIndex = Math.min(itemCount, startIndex + visibleCount);

  return { containerRef, startIndex, endIndex, totalHeight: itemCount * rowHeight, offsetY: startIndex * rowHeight };
}
