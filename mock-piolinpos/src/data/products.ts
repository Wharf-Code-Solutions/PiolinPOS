import catalogo from "./catalogo.json";
import type { Product, ProductCategory } from "../types";

const CATEGORY_LABELS: Record<string, ProductCategory> = {
  taco: "Tacos",
  torta: "Tortas",
  super_torta: "Tortas",
  refresco: "Refrescos",
};

export const INGREDIENTE_LABELS: Record<string, string> = {
  milanesa: "Milanesa",
  jamon: "Jamón",
  pierna: "Pierna",
};

function shortKey(id: number, categoria: string): string {
  if (categoria === "super_torta") return "ST";
  const prefix = categoria === "taco" ? "T" : categoria === "torta" ? "TO" : "R";
  return `${prefix}${id}`;
}

export const PRODUCTS: Product[] = catalogo.productos.map((p) => ({
  id: p.id,
  key: shortKey(p.id, p.categoria),
  name: p.nombre,
  category: CATEGORY_LABELS[p.categoria],
  price: p.precio,
  isSuperTorta: p.categoria === "super_torta",
  superTortaIngredientes: p.ingredientesPermitidos?.map((i) => INGREDIENTE_LABELS[i] ?? i),
}));

export const CATEGORIES: ProductCategory[] = ["Tacos", "Tortas", "Refrescos"];

export const SUPER_TORTA_MODOS = ["Mitad y mitad", "Revuelta"] as const;
