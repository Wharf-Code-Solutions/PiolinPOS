import { Minus, Plus, Trash2, MessageSquarePlus, User, UtensilsCrossed, ShoppingBag } from "lucide-react";
import type { CartLine } from "./cartTypes";
import type { DiningOption } from "../../types";

interface CartPanelProps {
  orderNumber: number;
  lines: CartLine[];
  total: number;
  customerName: string;
  onCustomerNameChange: (value: string) => void;
  diningOption: DiningOption;
  onDiningOptionChange: (value: DiningOption) => void;
  onIncrement: (cartId: string) => void;
  onDecrement: (cartId: string) => void;
  onRemove: (cartId: string) => void;
  onAddNote: (cartId: string) => void;
  onConfirm: () => void;
}

export function CartPanel({
  orderNumber,
  lines,
  total,
  customerName,
  onCustomerNameChange,
  diningOption,
  onDiningOptionChange,
  onIncrement,
  onDecrement,
  onRemove,
  onAddNote,
  onConfirm,
}: CartPanelProps) {
  const isEmpty = lines.length === 0;

  return (
    <div className="flex h-full flex-col bg-white">
      <div className="border-b border-ink-200 px-5 py-4">
        <div className="mb-3 flex items-baseline justify-between">
          <h2 className="text-[13px] font-bold uppercase tracking-wide text-ink-500">Pedido</h2>
          <span className="text-[15px] font-bold text-ink-900">#{orderNumber}</span>
        </div>
        <label className="mb-2.5 flex items-center gap-2 rounded-lg bg-ink-50 px-3 py-2.5 ring-1 ring-inset ring-ink-200 focus-within:ring-piolin-400">
          <User className="h-4 w-4 shrink-0 text-ink-400" />
          <input
            value={customerName}
            onChange={(e) => onCustomerNameChange(e.target.value)}
            placeholder="Nombre del cliente (opcional)"
            className="w-full bg-transparent text-[14px] font-medium text-ink-900 outline-none placeholder:text-ink-400"
          />
        </label>

        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={() => onDiningOptionChange("Comer aquí")}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2.5 text-[13.5px] font-bold transition-colors ${
              diningOption === "Comer aquí"
                ? "bg-piolin-600 text-white"
                : "bg-ink-50 text-ink-500 ring-1 ring-inset ring-ink-200"
            }`}
          >
            <UtensilsCrossed className="h-4 w-4" />
            Comer aquí
          </button>
          <button
            onClick={() => onDiningOptionChange("Para llevar")}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2.5 text-[13.5px] font-bold transition-colors ${
              diningOption === "Para llevar"
                ? "bg-piolin-600 text-white"
                : "bg-ink-50 text-ink-500 ring-1 ring-inset ring-ink-200"
            }`}
          >
            <ShoppingBag className="h-4 w-4" />
            Para llevar
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-5 py-3">
        {isEmpty ? (
          <div className="flex h-full flex-col items-center justify-center gap-1 py-10 text-center">
            <p className="text-[15px] text-ink-400">Aún no hay productos en el pedido.</p>
            <p className="text-[13px] text-ink-300">Toca un producto para agregarlo.</p>
          </div>
        ) : (
          <ul className="flex flex-col gap-3">
            {lines.map((line) => (
              <li key={line.cartId} className="rounded-lg border border-ink-100 bg-ink-50/60 p-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5">
                      <span className="rounded bg-ink-100 px-1.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-ink-500">
                        {line.key}
                      </span>
                      {line.variant && (
                        <span className="rounded bg-ink-100 px-1.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-ink-600">
                          {line.variant}
                        </span>
                      )}
                    </div>
                    <p className="mt-1 truncate text-[15px] font-semibold text-ink-900">{line.name}</p>
                    <p className="text-[13px] text-ink-500">
                      ${line.unitPrice} c/u · ${line.unitPrice * line.quantity}
                    </p>
                    {line.notes && (
                      <p className="mt-1 inline-block rounded bg-piolin-100 px-1.5 py-0.5 text-[12px] font-semibold uppercase tracking-wide text-piolin-700">
                        {line.notes}
                      </p>
                    )}
                  </div>
                  <button
                    onClick={() => onRemove(line.cartId)}
                    aria-label={`Quitar ${line.name}`}
                    className="shrink-0 rounded-md p-1.5 text-ink-400 active:bg-ink-100"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>

                <div className="mt-2.5 flex items-center justify-between">
                  <div className="flex items-center gap-1 rounded-lg bg-white ring-1 ring-inset ring-ink-200">
                    <button
                      onClick={() => onDecrement(line.cartId)}
                      aria-label="Disminuir cantidad"
                      className="flex h-10 w-10 items-center justify-center text-ink-600 active:bg-ink-50"
                    >
                      <Minus className="h-4 w-4" />
                    </button>
                    <span className="w-6 text-center text-[16px] font-bold tabular-nums text-ink-900">
                      {line.quantity}
                    </span>
                    <button
                      onClick={() => onIncrement(line.cartId)}
                      aria-label="Aumentar cantidad"
                      className="flex h-10 w-10 items-center justify-center text-ink-600 active:bg-ink-50"
                    >
                      <Plus className="h-4 w-4" />
                    </button>
                  </div>
                  <button
                    onClick={() => onAddNote(line.cartId)}
                    className="flex items-center gap-1 rounded-md px-2 py-1.5 text-[13px] font-semibold text-ink-500 active:bg-ink-100"
                  >
                    <MessageSquarePlus className="h-3.5 w-3.5" />
                    {line.notes ? "Editar nota" : "Nota"}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="border-t border-ink-200 px-5 py-4">
        <div className="mb-3 flex items-baseline justify-between">
          <span className="text-[15px] font-semibold text-ink-600">Total</span>
          <span className="font-display text-[28px] font-semibold tabular-nums text-ink-950">
            ${total.toFixed(2)}
          </span>
        </div>
        <button
          onClick={onConfirm}
          disabled={isEmpty}
          className="w-full rounded-xl bg-piolin-600 py-4 text-[17px] font-bold text-white shadow-sm transition-transform active:scale-[0.98] disabled:cursor-not-allowed disabled:bg-ink-200 disabled:text-ink-400"
        >
          Confirmar pedido
        </button>
      </div>
    </div>
  );
}
