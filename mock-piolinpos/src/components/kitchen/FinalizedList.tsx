import type { Order } from "../../types";

interface FinalizedListProps {
  orders: Order[];
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("es-MX", { hour: "2-digit", minute: "2-digit", hour12: false });
}

export function FinalizedList({ orders }: FinalizedListProps) {
  const recent = [...orders].sort((a, b) => b.id - a.id).slice(0, 8);

  return (
    <div>
      <h3 className="mb-2.5 text-[12px] font-bold uppercase tracking-wide text-ink-500">
        Finalizados
      </h3>
      {recent.length === 0 ? (
        <p className="text-[13px] text-ink-600">Sin pedidos finalizados aún.</p>
      ) : (
        <ul className="flex flex-wrap gap-2">
          {recent.map((order) => (
            <li
              key={order.id}
              className="flex items-center gap-2 rounded-lg bg-ink-900 px-3 py-2 text-[13px] font-semibold text-ink-400"
            >
              <span className="text-ink-200">#{order.id}</span>
              {order.finalizedAt && <span className="tabular-nums">{formatTime(order.finalizedAt)}</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
