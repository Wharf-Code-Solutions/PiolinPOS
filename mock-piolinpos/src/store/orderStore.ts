import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { DiningOption, Order, OrderItem, OrderStatus } from "../types";
import { DEMO_ORDERS, NEXT_ORDER_ID } from "../data/demoOrders";
import { CHANNEL_NAME, STORAGE_KEY, type SyncMessage } from "../utils/storage";

interface OrderStore {
  orders: Order[];
  nextId: number;
  /** Bumped on every externally-observed change; components can key off it for toasts. */
  lastEvent: SyncMessage | null;

  addOrder: (items: OrderItem[], diningOption: DiningOption, customerName?: string) => Order;
  finalizeOrder: (orderId: number) => void;
  resetDemo: () => void;
  setLastEvent: (event: SyncMessage | null) => void;
}

let channel: BroadcastChannel | null = null;
function getChannel(): BroadcastChannel | null {
  if (typeof window === "undefined" || !("BroadcastChannel" in window)) return null;
  if (!channel) channel = new BroadcastChannel(CHANNEL_NAME);
  return channel;
}

function broadcast(message: SyncMessage) {
  getChannel()?.postMessage(message);
}

export const useOrderStore = create<OrderStore>()(
  persist(
    (set, get) => ({
      orders: DEMO_ORDERS,
      nextId: NEXT_ORDER_ID,
      lastEvent: null,

      addOrder: (items, diningOption, customerName) => {
        const order: Order = {
          id: get().nextId,
          items,
          customerName,
          diningOption,
          status: "PENDIENTE",
          createdAt: new Date().toISOString(),
        };
        set((state) => ({
          orders: [...state.orders, order],
          nextId: state.nextId + 1,
        }));
        broadcast({ type: "ORDER_SENT", orderId: order.id });
        return order;
      },

      finalizeOrder: (orderId) => {
        set((state) => ({
          orders: state.orders.map((o) =>
            o.id === orderId
              ? { ...o, status: "FINALIZADO" as OrderStatus, finalizedAt: new Date().toISOString() }
              : o,
          ),
        }));
        broadcast({ type: "ORDER_FINALIZED", orderId });
      },

      resetDemo: () => {
        set({ orders: DEMO_ORDERS, nextId: NEXT_ORDER_ID, lastEvent: null });
        broadcast({ type: "STORE_RESET" });
      },

      setLastEvent: (event) => set({ lastEvent: event }),
    }),
    {
      name: STORAGE_KEY,
      partialize: (state) => ({ orders: state.orders, nextId: state.nextId }),
    },
  ),
);

/**
 * Cross-tab wiring. Two complementary mechanisms:
 * - `storage` events fire natively in *other* tabs whenever localStorage changes,
 *   so we rehydrate the persisted state from disk to pick up the change.
 * - BroadcastChannel carries a lightweight semantic event (what happened, to which
 *   order) so the UI can show a precise "Pedido #1042 enviado a cocina" style toast
 *   instead of just noticing the data changed.
 */
export function initOrderStoreSync() {
  if (typeof window === "undefined") return () => {};

  const handleStorage = (e: StorageEvent) => {
    if (e.key === STORAGE_KEY) {
      useOrderStore.persist.rehydrate();
    }
  };
  window.addEventListener("storage", handleStorage);

  const bc = getChannel();
  const handleMessage = (e: MessageEvent<SyncMessage>) => {
    // Ensure latest persisted state is loaded, then surface the event for toasts.
    useOrderStore.persist.rehydrate();
    useOrderStore.getState().setLastEvent(e.data);
  };
  bc?.addEventListener("message", handleMessage);

  return () => {
    window.removeEventListener("storage", handleStorage);
    bc?.removeEventListener("message", handleMessage);
  };
}
