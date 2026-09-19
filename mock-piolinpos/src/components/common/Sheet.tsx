import { type ReactNode, useEffect } from "react";

interface SheetProps {
  children: ReactNode;
  onClose: () => void;
  wide?: boolean;
}

/**
 * A bottom sheet on small/tablet widths, centered dialog on larger ones.
 * Deliberately plain: one surface, one purpose, no decorative chrome.
 */
export function Sheet({ children, onClose, wide }: SheetProps) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-ink-950/40 sm:items-center">
      <button
        aria-label="Cerrar"
        onClick={onClose}
        className="absolute inset-0 h-full w-full cursor-default"
        tabIndex={-1}
      />
      <div
        className={`relative w-full ${wide ? "sm:max-w-lg" : "sm:max-w-sm"} rounded-t-2xl bg-white shadow-xl sm:rounded-2xl`}
      >
        {children}
      </div>
    </div>
  );
}
