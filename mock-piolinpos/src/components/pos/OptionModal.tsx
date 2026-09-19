import { X } from "lucide-react";
import { Sheet } from "../common/Sheet";
import type { Product } from "../../types";

interface OptionModalProps {
  product: Product;
  /** e.g. "Elige el sabor" or "Elige el topping". */
  subtitle: string;
  options: string[];
  onPick: (option: string) => void;
  onClose: () => void;
}

/** Generic single-pick bottom sheet, used for taco flavors and burger toppings. */
export function OptionModal({ product, subtitle, options, onPick, onClose }: OptionModalProps) {
  return (
    <Sheet onClose={onClose}>
      <div className="flex items-center justify-between px-5 pt-5">
        <div>
          <span className="text-[12px] font-bold uppercase tracking-wide text-piolin-600">{product.key}</span>
          <h3 className="text-[17px] font-bold leading-snug text-ink-900">{product.name}</h3>
          <p className="mt-0.5 text-[13px] font-semibold text-ink-500">{subtitle}</p>
        </div>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>

      <div className="flex flex-col gap-2.5 px-5 pb-5 pt-4">
        {options.map((opt) => (
          <button
            key={opt}
            onClick={() => onPick(opt)}
            className="flex items-center justify-between rounded-xl border border-ink-200 px-5 py-4 text-left active:border-piolin-500 active:bg-piolin-50"
          >
            <span className="text-[17px] font-bold text-ink-900">{opt}</span>
          </button>
        ))}
      </div>
    </Sheet>
  );
}
