import { Check, Receipt, UtensilsCrossed, ShoppingBag, AlertTriangle } from "lucide-react";
import type { Order } from "../../types";

interface OrderCardProps {
  order: Order;
  onFinalize: (id: number) => void;
  onShowTicket: (id: number) => void;
  justArrived?: boolean;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("es-MX", { hour: "2-digit", minute: "2-digit", hour12: false });
}

function minutesSince(iso: string): number {
  return Math.floor((Date.now() - new Date(iso).getTime()) / 60_000);
}

export function OrderCard({ order, onFinalize, onShowTicket, justArrived }: OrderCardProps) {
  const notes = Array.from(new Set(order.items.map((it) => it.notes).filter(Boolean))) as string[];
  const waitMin = minutesSince(order.createdAt);
  const isWarn = waitMin >= 6 && waitMin < 10;
  const isLate = waitMin >= 10;

  return (
    <div
      className={`flex flex-col rounded-xl border bg-ink-900 p-4 shadow-sm transition-all sm:p-5 ${
        justArrived
          ? "border-piolin-500 ring-2 ring-piolin-500/40"
          : isLate
            ? "border-status-late"
            : "border-ink-700"
      }`}
    >
      <div className="mb-1 flex items-center justify-between">
        <span className="font-display text-[24px] font-semibold tracking-tight text-white sm:text-[28px]">
          #{order.id}
        </span>
        <div className="flex items-center gap-2">
          {isLate ? (
            <span className="flex items-center gap-1 rounded-md bg-status-late/20 px-2 py-1 text-[13px] font-bold tabular-nums text-status-late">
              <AlertTriangle className="h-3.5 w-3.5" />
              {waitMin} min esperando
            </span>
          ) : (
            <span
              className={`text-[14px] font-bold tabular-nums sm:text-[15px] ${
                isWarn ? "text-piolin-400" : "text-ink-400"
              }`}
            >
              {formatTime(order.createdAt)}
            </span>
          )}
          <button
            onClick={() => onShowTicket(order.id)}
            aria-label="Ver comanda impresa"
            className="rounded-md p-1.5 text-ink-500 active:bg-ink-800"
          >
            <Receipt className="h-4 w-4" />
          </button>
        </div>
      </div>

      <div className="mb-3 flex items-center gap-2">
        <span className="flex items-center gap-1.5 rounded-md bg-ink-800 px-2 py-1 text-[12.5px] font-bold uppercase tracking-wide text-ink-200">
          {order.diningOption === "Comer aquí" ? (
            <UtensilsCrossed className="h-3.5 w-3.5" />
          ) : (
            <ShoppingBag className="h-3.5 w-3.5" />
          )}
          {order.diningOption}
        </span>
        {order.customerName && (
          <span className="text-[15px] font-bold text-piolin-400 sm:text-[16px]">{order.customerName}</span>
        )}
      </div>

      <ul className="mb-3 flex flex-col gap-1.5">
        {order.items.map((item) => (
          <li
            key={item.productId + (item.sizeLabel ?? "") + (item.variant ?? "") + (item.notes ?? "")}
            className="flex items-baseline gap-2"
          >
            <span className="text-[20px] font-extrabold tabular-nums text-piolin-400 sm:text-[22px]">
              {item.quantity}×
            </span>
            <span className="rounded bg-ink-800 px-1.5 py-0.5 text-[12px] font-bold uppercase tracking-wide text-ink-400">
              {item.key}
            </span>
            <span className="text-[18px] font-semibold leading-snug text-ink-50 sm:text-[20px]">
              {item.name}
              {item.sizeLabel && <span className="text-ink-400"> · {item.sizeLabel}</span>}
              {item.variant && <span className="text-ink-400"> · {item.variant}</span>}
            </span>
          </li>
        ))}
      </ul>

      {notes.length > 0 && (
        <div className="mb-4 flex flex-wrap gap-1.5">
          {notes.map((n) => (
            <span
              key={n}
              className="rounded bg-piolin-500/15 px-2 py-1 text-[13px] font-bold uppercase tracking-wide text-piolin-400"
            >
              {n}
            </span>
          ))}
        </div>
      )}

      <button
        onClick={() => onFinalize(order.id)}
        className="mt-auto flex items-center justify-center gap-2 rounded-lg bg-piolin-600 py-4 text-[16px] font-bold text-white shadow-sm transition-transform active:scale-[0.97] sm:text-[17px]"
      >
        <Check className="h-5 w-5" strokeWidth={2.75} />
        Finalizar pedido
      </button>
    </div>
  );
}
