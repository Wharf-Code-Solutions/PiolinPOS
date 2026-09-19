import type { SizeLabel } from "../../types";

export interface CartLine {
  cartId: string;
  productId: string;
  key: string;
  name: string;
  unitPrice: number;
  quantity: number;
  sizeLabel?: SizeLabel;
  variant?: string;
  notes?: string;
}

let counter = 0;
export function newCartId(): string {
  return `c${Date.now()}-${counter++}`;
}

/** Merges incoming lines into the cart, combining quantities when product + size + variant + notes match. */
export function mergeCartLines(existing: CartLine[], incoming: CartLine[]): CartLine[] {
  let result = [...existing];
  for (const line of incoming) {
    const matchIndex = result.findIndex(
      (l) =>
        l.productId === line.productId &&
        (l.notes ?? "") === (line.notes ?? "") &&
        (l.sizeLabel ?? "") === (line.sizeLabel ?? "") &&
        (l.variant ?? "") === (line.variant ?? ""),
    );
    if (matchIndex !== -1) {
      const match = result[matchIndex];
      result = result.map((l, i) => (i === matchIndex ? { ...match, quantity: l.quantity + line.quantity } : l));
    } else {
      result = [...result, line];
    }
  }
  return result;
}
