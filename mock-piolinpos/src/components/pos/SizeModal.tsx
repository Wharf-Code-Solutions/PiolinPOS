import { X } from "lucide-react";
import { Sheet } from "../common/Sheet";
import type { Product, ProductSize } from "../../types";

interface SizeModalProps {
  product: Product;
  onPick: (size: ProductSize) => void;
  onClose: () => void;
}

export function SizeModal({ product, onPick, onClose }: SizeModalProps) {
  return (
    <Sheet onClose={onClose}>
      <div className="flex items-center justify-between px-5 pt-5">
        <div>
          <span className="text-[12px] font-bold uppercase tracking-wide text-piolin-600">
            {product.key}
          </span>
          <h3 className="text-[17px] font-bold leading-snug text-ink-900">{product.name}</h3>
        </div>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>

      <div className="flex flex-col gap-2.5 px-5 pb-5 pt-4">
        {product.sizes.map((size) => (
          <button
            key={size.label}
            onClick={() => onPick(size)}
            className="flex items-center justify-between rounded-xl border border-ink-200 px-5 py-4 text-left active:border-piolin-500 active:bg-piolin-50"
          >
            <span className="text-[17px] font-bold text-ink-900">{size.label}</span>
            <span className="font-display text-[19px] font-semibold text-ink-700">${size.price}</span>
          </button>
        ))}
      </div>
    </Sheet>
  );
}
