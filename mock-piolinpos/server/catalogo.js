import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Única fuente de verdad del catálogo — la misma que usa el frontend
// (src/data/catalogo.json), para que precios y sinónimos nunca diverjan.
const CATALOGO_PATH = path.join(__dirname, "..", "src", "data", "catalogo.json");

export function cargarCatalogo() {
  const raw = readFileSync(CATALOGO_PATH, "utf-8");
  return JSON.parse(raw).productos;
}

export const CATALOGO = cargarCatalogo();

export function buscarProducto(id) {
  return CATALOGO.find((p) => p.id === id);
}
