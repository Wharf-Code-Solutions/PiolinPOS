import type { Order } from "../../types";

interface RecentOrdersProps {
  orders: Order[];
}

function orderTotal(order: Order): number {
  return order.items.reduce((sum, it) => sum + it.unitPrice * it.quantity, 0);
}

export function RecentOrders({ orders }: RecentOrdersProps) {
  const recent = [...orders].sort((a, b) => b.id - a.id).slice(0, 5);
  if (recent.length === 0) return null;

  return (
    <div className="border-t border-ink-200 bg-white px-4 py-3 sm:px-6">
      <h3 className="mb-2 text-[12px] font-bold uppercase tracking-wide text-ink-500">
        Pedidos recientes
      </h3>
      <ul className="flex flex-wrap gap-2">
        {recent.map((order) => (
          <li
            key={order.id}
            className="flex items-center gap-2 rounded-lg bg-ink-50 px-3 py-2 text-[13px] font-semibold"
          >
            <span className="text-ink-900">#{order.id}</span>
            <span className="text-ink-500">${orderTotal(order)}</span>
            <span
              className={
                order.status === "PENDIENTE"
                  ? "rounded bg-status-pending-bg px-1.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-status-pending"
                  : "rounded bg-status-done-bg px-1.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-status-done"
              }
            >
              {order.status === "PENDIENTE" ? "Pendiente" : "Finalizado"}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
