import type { Order } from "../types";

// Timestamps are generated relative to "now" so the demo always looks fresh.
function minutesAgo(mins: number): string {
  return new Date(Date.now() - mins * 60_000).toISOString();
}

export const DEMO_ORDERS: Order[] = [
  {
    id: 1038,
    status: "FINALIZADO",
    customerName: "Lupita",
    diningOption: "Para llevar",
    createdAt: minutesAgo(52),
    finalizedAt: minutesAgo(46),
    items: [
      { productId: 1, key: "T1", name: "Taco de Asada", quantity: 3, unitPrice: 18 },
      { productId: 8, key: "R8", name: "Coca Cola", quantity: 1, unitPrice: 20 },
    ],
  },
  {
    id: 1039,
    status: "FINALIZADO",
    customerName: "Don Beto",
    diningOption: "Comer aquí",
    createdAt: minutesAgo(38),
    finalizedAt: minutesAgo(31),
    items: [
      {
        productId: 7,
        key: "ST",
        name: "Super Torta",
        quantity: 1,
        unitPrice: 65,
        variant: "Milanesa + Jamón",
        notes: "Mitad y mitad",
      },
      { productId: 9, key: "R9", name: "Agua de Sabor", quantity: 1, unitPrice: 18 },
    ],
  },
  {
    id: 1040,
    status: "FINALIZADO",
    diningOption: "Para llevar",
    createdAt: minutesAgo(24),
    finalizedAt: minutesAgo(18),
    items: [
      { productId: 2, key: "T2", name: "Taco de Pastor", quantity: 5, unitPrice: 16, notes: "Sin cebolla" },
      { productId: 8, key: "R8", name: "Coca Cola", quantity: 1, unitPrice: 20 },
    ],
  },
  {
    id: 1041,
    status: "PENDIENTE",
    customerName: "Ing. Ramírez",
    diningOption: "Comer aquí",
    createdAt: minutesAgo(6),
    items: [
      { productId: 6, key: "TO6", name: "Torta de Pierna", quantity: 1, unitPrice: 42 },
      { productId: 3, key: "T3", name: "Taco de Suadero", quantity: 2, unitPrice: 17 },
    ],
  },
];

export const NEXT_ORDER_ID = 1042;
