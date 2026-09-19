export type OrderStatus = "PENDIENTE" | "FINALIZADO";

export type ProductCategory = "Tortas" | "Bebidas" | "Snacks";

export type SizeLabel = "Sencillo" | "Súper";

export type DiningOption = "Comer aquí" | "Para llevar";

export interface ProductSize {
  label: SizeLabel;
  price: number;
  /** If set, picking this size requires an extra pick from this list (e.g. burger topping). */
  toppingOptions?: string[];
}

export interface Product {
  id: string;
  /** Short menu code shown to the operator, e.g. "A1". */
  key: string;
  name: string;
  category: ProductCategory;
  /** Always at least one size. A single entry means the product has no size choice. */
  sizes: ProductSize[];
  /**
   * When set, replaces the Sencillo/Súper size picker with a flat pick from this
   * list (e.g. taco flavor) — every option shares the single price in `sizes[0]`.
   */
  variantOptions?: string[];
  available: boolean;
}

export interface OrderItem {
  productId: string;
  key: string;
  name: string;
  quantity: number;
  unitPrice: number;
  sizeLabel?: SizeLabel;
  /** Flavor (from variantOptions) or topping (from a size's toppingOptions), when applicable. */
  variant?: string;
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
