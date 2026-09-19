import { X } from "lucide-react";
import { Sheet } from "../common/Sheet";
import type { Order } from "../../types";

interface ReceiptPreviewProps {
  order: Order;
  onClose: () => void;
}

/** A stand-in for what a thermal kitchen printer would output — demo only. */
export function ReceiptPreview({ order, onClose }: ReceiptPreviewProps) {
  const notes = Array.from(new Set(order.items.map((it) => it.notes).filter(Boolean))) as string[];
  const width = 32;
  const rule = "=".repeat(width);
  const thin = "-".repeat(width);

  const lines: string[] = [];
  lines.push(rule);
  lines.push("PIOLINPOS".padStart(Math.floor((width + 9) / 2)));
  lines.push(rule);
  lines.push("");
  lines.push(`PEDIDO #${order.id}`);
  lines.push(order.diningOption.toUpperCase());
  if (order.customerName) {
    lines.push(`CLIENTE: ${order.customerName.toUpperCase()}`);
  }
  lines.push("");
  for (const item of order.items) {
    const size = item.sizeLabel ? ` (${item.sizeLabel.toUpperCase()})` : "";
    const variant = item.variant ? ` - ${item.variant.toUpperCase()}` : "";
    lines.push(`${item.quantity} × [${item.key}] ${item.name.toUpperCase()}${size}${variant}`);
  }
  if (notes.length > 0) {
    lines.push("");
    lines.push(thin);
    lines.push("");
    for (const n of notes) lines.push(n.toUpperCase());
  }
  lines.push("");
  lines.push(rule);

  return (
    <Sheet onClose={onClose}>
      <div className="flex items-center justify-between px-5 pt-5">
        <h3 className="text-[15px] font-bold uppercase tracking-wide text-ink-500">
          Vista previa de comanda
        </h3>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>
      <div className="px-5 pb-6 pt-4">
        <pre className="whitespace-pre-wrap rounded-lg bg-ink-50 p-4 text-center font-mono text-[13px] leading-relaxed text-ink-800">
          {lines.join("\n")}
        </pre>
      </div>
    </Sheet>
  );
}
