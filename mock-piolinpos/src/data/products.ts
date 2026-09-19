import type { Product } from "../types";

export const PRODUCTS: Product[] = [
  // Tortas — A
  {
    id: "torta-jamon-amarillo",
    key: "A1",
    name: "Torta de Jamón con Queso Amarillo",
    category: "Tortas",
    available: true,
    sizes: [
      { label: "Sencillo", price: 55 },
      { label: "Súper", price: 70 },
    ],
  },
  {
    id: "torta-jamon-hebra",
    key: "A2",
    name: "Torta de Jamón con Queso Hebra",
    category: "Tortas",
    available: true,
    sizes: [
      { label: "Sencillo", price: 60 },
      { label: "Súper", price: 75 },
    ],
  },
  {
    id: "cuerno-4-quesos",
    key: "A3",
    name: "Cuerno de 4 Quesos",
    category: "Tortas",
    available: true,
    sizes: [
      { label: "Sencillo", price: 65 },
      { label: "Súper", price: 80 },
    ],
  },
  {
    id: "promo-tacos",
    key: "A4",
    name: "Promo Tacos",
    category: "Tortas",
    available: true,
    // Flat price regardless of flavor — variantOptions replaces the size picker.
    sizes: [{ label: "Sencillo", price: 50 }],
    variantOptions: ["Pastor", "Milanesa", "Carnitas"],
  },
  {
    id: "hamburguesa",
    key: "A5",
    name: "Hamburguesa",
    category: "Tortas",
    available: true,
    sizes: [
      { label: "Sencillo", price: 75 },
      { label: "Súper", price: 90, toppingOptions: ["Tocino", "Chistorra", "Salchicha"] },
    ],
  },

  // Bebidas — B
  {
    id: "coca-600",
    key: "B1",
    name: "Coca-Cola 600 ml",
    category: "Bebidas",
    available: true,
    sizes: [{ label: "Sencillo", price: 25 }],
  },
  {
    id: "agua-natural",
    key: "B2",
    name: "Agua Natural",
    category: "Bebidas",
    available: true,
    sizes: [{ label: "Sencillo", price: 15 }],
  },
  {
    id: "pepsi-600",
    key: "B3",
    name: "Pepsi 600 ml",
    category: "Bebidas",
    available: true,
    sizes: [{ label: "Sencillo", price: 22 }],
  },
  {
    id: "agua-mineral",
    key: "B4",
    name: "Agua Mineral",
    category: "Bebidas",
    available: true,
    sizes: [{ label: "Sencillo", price: 20 }],
  },

  // Snacks — C
  {
    id: "papas",
    key: "C1",
    name: "Papas",
    category: "Snacks",
    available: true,
    sizes: [{ label: "Sencillo", price: 25 }],
  },
  {
    id: "galletas",
    key: "C2",
    name: "Galletas",
    category: "Snacks",
    available: true,
    sizes: [{ label: "Sencillo", price: 18 }],
  },
  {
    id: "sabritas",
    key: "C3",
    name: "Sabritas",
    category: "Snacks",
    available: true,
    sizes: [{ label: "Sencillo", price: 20 }],
  },
];

export const CATEGORIES: Product["category"][] = ["Tortas", "Bebidas", "Snacks"];

export function hasSizeChoice(product: Product): boolean {
  return product.sizes.length > 1;
}

export function hasVariantChoice(product: Product): boolean {
  return !!product.variantOptions && product.variantOptions.length > 0;
}
