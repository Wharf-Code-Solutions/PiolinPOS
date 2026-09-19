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
      {
        productId: "hamburguesa",
        key: "A5",
        name: "Hamburguesa",
        quantity: 1,
        unitPrice: 90,
        sizeLabel: "Súper",
        variant: "Tocino",
      },
      { productId: "agua-natural", key: "B2", name: "Agua Natural", quantity: 1, unitPrice: 15 },
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
        productId: "torta-jamon-amarillo",
        key: "A1",
        name: "Torta de Jamón con Queso Amarillo",
        quantity: 2,
        unitPrice: 70,
        sizeLabel: "Súper",
      },
      { productId: "pepsi-600", key: "B3", name: "Pepsi 600 ml", quantity: 2, unitPrice: 22 },
    ],
  },
  {
    id: 1040,
    status: "FINALIZADO",
    diningOption: "Para llevar",
    createdAt: minutesAgo(24),
    finalizedAt: minutesAgo(18),
    items: [
      { productId: "sabritas", key: "C3", name: "Sabritas", quantity: 1, unitPrice: 20 },
      { productId: "coca-600", key: "B1", name: "Coca-Cola 600 ml", quantity: 1, unitPrice: 25 },
      {
        productId: "cuerno-4-quesos",
        key: "A3",
        name: "Cuerno de 4 Quesos",
        quantity: 1,
        unitPrice: 65,
        sizeLabel: "Sencillo",
      },
    ],
  },
  {
    id: 1041,
    status: "PENDIENTE",
    customerName: "Ing. Ramírez",
    diningOption: "Comer aquí",
    createdAt: minutesAgo(6),
    items: [
      {
        productId: "torta-jamon-hebra",
        key: "A2",
        name: "Torta de Jamón con Queso Hebra",
        quantity: 1,
        unitPrice: 60,
        sizeLabel: "Sencillo",
      },
      { productId: "agua-mineral", key: "B4", name: "Agua Mineral", quantity: 2, unitPrice: 20 },
    ],
  },
];

export const NEXT_ORDER_ID = 1042;
