export type OrderStatus = "PENDIENTE" | "FINALIZADO";

export type ProductCategory = "Tacos" | "Tortas" | "Refrescos";

export type DiningOption = "Comer aquí" | "Para llevar";

export type SuperTortaModo = "Mitad y mitad" | "Revuelta";

export interface Product {
  id: number;
  /** Short menu code shown to the operator, e.g. "T1". */
  key: string;
  name: string;
  category: ProductCategory;
  price: number;
  /** Only set on the Super Torta product — picking it opens the ingredient/modo picker instead of adding directly. */
  isSuperTorta?: boolean;
  /** Only set on the Super Torta product: the ingredients the operator can combine, exactly 2 per order. */
  superTortaIngredientes?: string[];
}

export interface OrderItem {
  productId: number;
  key: string;
  name: string;
  quantity: number;
  unitPrice: number;
  /** Super Torta ingredient combo, e.g. "Milanesa + Jamón". */
  variant?: string;
  /** Free-form: "Sin cebolla", "Mitad y mitad (por defecto)", "Revuelta", etc. */
  notes?: string;
}

export interface Order {
  id: number;
  items: OrderItem[];
  status: OrderStatus;
  /** Name of the customer who placed the order, shown on the kitchen ticket. */
  customerName?: string;
  /** Whether the order is for dine-in or takeout — always set, never folded into notes. */
  diningOption: DiningOption;
  notes?: string;
  createdAt: string;
  finalizedAt?: string;
}
