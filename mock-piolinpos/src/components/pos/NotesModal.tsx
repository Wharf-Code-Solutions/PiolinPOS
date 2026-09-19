import { useState } from "react";
import { X } from "lucide-react";
import { Sheet } from "../common/Sheet";

interface NotesModalProps {
  productName: string;
  initialValue: string;
  onSave: (value: string) => void;
  onClose: () => void;
}

const SUGGESTIONS = ["Sin cebolla", "Sin chile", "Bien caliente", "Extra salsa"];

export function NotesModal({ productName, initialValue, onSave, onClose }: NotesModalProps) {
  const [value, setValue] = useState(initialValue);

  return (
    <Sheet onClose={onClose}>
      <div className="flex items-center justify-between px-5 pt-5">
        <h3 className="text-[17px] font-bold text-ink-900">{productName}</h3>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>

      <div className="px-5 pb-2 pt-4">
        <label className="mb-1.5 block text-[13px] font-semibold uppercase tracking-wide text-ink-500">
          Observaciones
        </label>
        <input
          autoFocus
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder="Ej. Sin cebolla"
          className="w-full rounded-lg border border-ink-200 px-4 py-3.5 text-[16px] text-ink-900 outline-none focus:border-piolin-500 focus:ring-2 focus:ring-piolin-100"
        />
        <div className="mt-3 flex flex-wrap gap-2">
          {SUGGESTIONS.map((s) => (
            <button
              key={s}
              onClick={() => setValue(s)}
              className="rounded-full bg-ink-50 px-3.5 py-2 text-[13px] font-semibold text-ink-600 ring-1 ring-inset ring-ink-200 active:bg-ink-100"
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      <div className="flex gap-3 px-5 pb-5 pt-4">
        <button
          onClick={onClose}
          className="flex-1 rounded-xl py-3.5 text-[15px] font-semibold text-ink-600 ring-1 ring-inset ring-ink-200 active:bg-ink-50"
        >
          Cancelar
        </button>
        <button
          onClick={() => onSave(value.trim())}
          className="flex-1 rounded-xl bg-piolin-600 py-3.5 text-[15px] font-bold text-white active:scale-[0.98]"
        >
          Guardar
        </button>
      </div>
    </Sheet>
  );
}
