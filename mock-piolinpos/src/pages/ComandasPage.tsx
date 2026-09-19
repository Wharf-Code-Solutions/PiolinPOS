import { useEffect, useMemo, useState } from "react";
import { OrderCard } from "../components/kitchen/OrderCard";
import { FinalizedList } from "../components/kitchen/FinalizedList";
import { ReceiptPreview } from "../components/kitchen/ReceiptPreview";
import { ResetDemoButton } from "../components/common/ResetDemoButton";
import { ToastStack } from "../components/common/Toast";
import { useToasts } from "../components/common/useToasts";
import { useOrderStore } from "../store/orderStore";

export function ComandasPage() {
  const orders = useOrderStore((s) => s.orders);
  const finalizeOrder = useOrderStore((s) => s.finalizeOrder);
  const lastEvent = useOrderStore((s) => s.lastEvent);

  const [now, setNow] = useState(() => new Date());
  const [ticketOrderId, setTicketOrderId] = useState<number | null>(null);
  const [arrivedId, setArrivedId] = useState<number | null>(null);
  const { toasts, push, dismiss } = useToasts();

  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 30_000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (lastEvent?.type === "ORDER_SENT") {
      setArrivedId(lastEvent.orderId);
      push(`Nuevo pedido #${lastEvent.orderId}`);
      const t = setTimeout(() => setArrivedId((id) => (id === lastEvent.orderId ? null : id)), 2200);
      return () => clearTimeout(t);
    }
  }, [lastEvent, push]);

  const pending = useMemo(
    () => [...orders].filter((o) => o.status === "PENDIENTE").sort((a, b) => a.id - b.id),
    [orders],
  );
  const finalized = useMemo(() => orders.filter((o) => o.status === "FINALIZADO"), [orders]);
  const ticketOrder = orders.find((o) => o.id === ticketOrderId);

  function handleFinalize(id: number) {
    finalizeOrder(id);
    push(`Pedido #${id} finalizado`);
  }

  return (
    <div className="flex h-full min-h-0 flex-1 flex-col bg-ink-950">
      <header className="flex items-center justify-between border-b border-ink-800 px-4 py-3.5 sm:px-6">
        <div>
          <h1 className="font-display text-[19px] font-semibold italic tracking-tight text-white">
            PiolinPOS
          </h1>
          <p className="text-[11px] font-bold uppercase tracking-wide text-ink-500">Comandas · Cocina</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5 rounded-full bg-ink-900 px-3.5 py-1.5 ring-1 ring-inset ring-ink-800">
            <span className="text-[12.5px] font-semibold text-ink-400">Pendientes</span>
            <span className="font-display text-[15px] font-bold text-piolin-400">{pending.length}</span>
          </div>
          <span className="text-[15px] font-bold tabular-nums text-ink-300">
            {now.toLocaleTimeString("es-MX", { hour: "2-digit", minute: "2-digit", hour12: false })}
          </span>
          <ResetDemoButton variant="dark" />
        </div>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-5 sm:px-6">
        <h2 className="mb-3 text-[13px] font-bold uppercase tracking-wide text-ink-500">
          Pendientes {pending.length > 0 && `(${pending.length})`}
        </h2>

        {pending.length === 0 ? (
          <p className="rounded-lg border border-dashed border-ink-800 py-10 text-center text-[15px] text-ink-600">
            No hay pedidos pendientes.
          </p>
        ) : (
          <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-2 sm:gap-4 xl:grid-cols-3">
            {pending.map((order) => (
              <OrderCard
                key={order.id}
                order={order}
                onFinalize={handleFinalize}
                onShowTicket={setTicketOrderId}
                justArrived={order.id === arrivedId}
              />
            ))}
          </div>
        )}

        <div className="mt-8 border-t border-ink-800 pt-5">
          <FinalizedList orders={finalized} />
        </div>
      </div>

      {ticketOrder && <ReceiptPreview order={ticketOrder} onClose={() => setTicketOrderId(null)} />}

      <ToastStack toasts={toasts} onDismiss={dismiss} />
    </div>
  );
}
