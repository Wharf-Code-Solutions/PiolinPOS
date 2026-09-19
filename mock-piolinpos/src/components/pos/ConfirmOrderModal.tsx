import { UtensilsCrossed, ShoppingBag } from "lucide-react";
import { Sheet } from "../common/Sheet";
import type { CartLine } from "./cartTypes";
import type { DiningOption } from "../../types";

interface ConfirmOrderModalProps {
  lines: CartLine[];
  total: number;
  customerName: string;
  diningOption: DiningOption;
  onBack: () => void;
  onConfirm: () => void;
}

export function ConfirmOrderModal({
  lines,
  total,
  customerName,
  diningOption,
  onBack,
  onConfirm,
}: ConfirmOrderModalProps) {
  const allNotes = Array.from(new Set(lines.map((l) => l.notes).filter(Boolean))) as string[];

  return (
    <Sheet onClose={onBack} wide>
      <div className="px-5 pt-5">
        <div className="flex items-center justify-between">
          <h3 className="text-[17px] font-bold text-ink-900">Confirmar pedido</h3>
          <span className="flex items-center gap-1.5 rounded-full bg-piolin-50 px-3 py-1 text-[12.5px] font-bold text-piolin-700">
            {diningOption === "Comer aquí" ? (
              <UtensilsCrossed className="h-3.5 w-3.5" />
            ) : (
              <ShoppingBag className="h-3.5 w-3.5" />
            )}
            {diningOption}
          </span>
        </div>
        {customerName.trim() && (
          <p className="mt-0.5 text-[14px] font-medium text-ink-500">Para: {customerName.trim()}</p>
        )}
      </div>

      <div className="max-h-[45vh] overflow-y-auto px-5 py-4">
        <ul className="flex flex-col gap-2.5">
          {lines.map((line) => (
            <li key={line.cartId} className="flex items-baseline justify-between gap-3">
              <span className="text-[15px] font-medium text-ink-800">
                {line.quantity} × {line.name}
                {line.sizeLabel && <span className="text-ink-500"> ({line.sizeLabel})</span>}
                {line.variant && <span className="text-ink-500"> · {line.variant}</span>}
              </span>
              <span className="shrink-0 text-[15px] font-semibold text-ink-600">
                ${line.unitPrice * line.quantity}
              </span>
            </li>
          ))}
        </ul>

        {allNotes.length > 0 && (
          <div className="mt-4 border-t border-ink-100 pt-3">
            <p className="mb-1.5 text-[12px] font-bold uppercase tracking-wide text-ink-500">
              Observaciones
            </p>
            <div className="flex flex-wrap gap-1.5">
              {allNotes.map((n) => (
                <span
                  key={n}
                  className="rounded bg-piolin-100 px-2 py-1 text-[12.5px] font-semibold uppercase tracking-wide text-piolin-700"
                >
                  {n}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="border-t border-ink-200 px-5 py-4">
        <div className="mb-4 flex items-baseline justify-between">
          <span className="text-[15px] font-semibold text-ink-600">Total</span>
          <span className="font-display text-[28px] font-semibold tabular-nums text-ink-950">
            ${total.toFixed(2)}
          </span>
        </div>
        <div className="flex gap-3">
          <button
            onClick={onBack}
            className="flex-1 rounded-xl py-3.5 text-[15px] font-semibold text-ink-600 ring-1 ring-inset ring-ink-200 active:bg-ink-50"
          >
            Regresar
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 rounded-xl bg-piolin-600 py-3.5 text-[15px] font-bold text-white active:scale-[0.98]"
          >
            Confirmar y enviar
          </button>
        </div>
      </div>
    </Sheet>
  );
}
