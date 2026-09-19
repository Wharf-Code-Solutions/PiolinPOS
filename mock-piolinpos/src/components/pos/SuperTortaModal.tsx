import { useState } from "react";
import { X } from "lucide-react";
import { Sheet } from "../common/Sheet";
import { SUPER_TORTA_MODOS } from "../../data/products";
import type { Product, SuperTortaModo } from "../../types";

interface SuperTortaModalProps {
  product: Product;
  onPick: (ingredientes: [string, string], modo: SuperTortaModo) => void;
  onClose: () => void;
}

/** Super Torta: siempre exactamente 2 ingredientes, precio fijo sin importar cuáles. */
export function SuperTortaModal({ product, onPick, onClose }: SuperTortaModalProps) {
  const opciones = product.superTortaIngredientes ?? [];
  const [seleccionados, setSeleccionados] = useState<string[]>([]);
  const [modo, setModo] = useState<SuperTortaModo>("Mitad y mitad");

  function toggleIngrediente(ingrediente: string) {
    setSeleccionados((prev) => {
      if (prev.includes(ingrediente)) return prev.filter((i) => i !== ingrediente);
      if (prev.length >= 2) return [prev[1], ingrediente];
      return [...prev, ingrediente];
    });
  }

  const listo = seleccionados.length === 2;

  return (
    <Sheet onClose={onClose}>
      <div className="flex items-center justify-between px-5 pt-5">
        <div>
          <span className="text-[12px] font-bold uppercase tracking-wide text-piolin-600">{product.key}</span>
          <h3 className="text-[17px] font-bold leading-snug text-ink-900">{product.name}</h3>
          <p className="mt-0.5 text-[13px] font-semibold text-ink-500">Elige exactamente 2 ingredientes</p>
        </div>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>

      <div className="flex flex-col gap-2.5 px-5 pb-2 pt-4">
        {opciones.map((ingrediente) => {
          const activo = seleccionados.includes(ingrediente);
          return (
            <button
              key={ingrediente}
              onClick={() => toggleIngrediente(ingrediente)}
              className={`flex items-center justify-between rounded-xl border px-5 py-4 text-left ${
                activo
                  ? "border-piolin-500 bg-piolin-50"
                  : "border-ink-200 active:border-piolin-500 active:bg-piolin-50"
              }`}
            >
              <span className="text-[17px] font-bold text-ink-900">{ingrediente}</span>
              {activo && (
                <span className="rounded-full bg-piolin-600 px-2 py-0.5 text-[12px] font-bold text-white">
                  {seleccionados.indexOf(ingrediente) + 1}
                </span>
              )}
            </button>
          );
        })}
      </div>

      <div className="px-5 pb-2 pt-3">
        <p className="mb-2 text-[13px] font-bold uppercase tracking-wide text-ink-500">Modo</p>
        <div className="grid grid-cols-2 gap-2">
          {SUPER_TORTA_MODOS.map((m) => (
            <button
              key={m}
              onClick={() => setModo(m)}
              className={`rounded-lg py-2.5 text-[13.5px] font-bold transition-colors ${
                modo === m ? "bg-piolin-600 text-white" : "bg-ink-50 text-ink-500 ring-1 ring-inset ring-ink-200"
              }`}
            >
              {m}
            </button>
          ))}
        </div>
      </div>

      <div className="px-5 pb-5 pt-4">
        <button
          onClick={() => listo && onPick([seleccionados[0], seleccionados[1]], modo)}
          disabled={!listo}
          className="w-full rounded-xl bg-piolin-600 py-3.5 text-[15px] font-bold text-white active:scale-[0.98] disabled:cursor-not-allowed disabled:bg-ink-200 disabled:text-ink-400"
        >
          {listo ? `Agregar: ${seleccionados.join(" + ")}` : "Selecciona 2 ingredientes"}
        </button>
      </div>
    </Sheet>
  );
}
