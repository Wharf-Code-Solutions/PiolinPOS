import { useEffect, useState } from "react";
import { RotateCcw } from "lucide-react";
import { useOrderStore } from "../../store/orderStore";

interface ResetDemoButtonProps {
  /** "light" for the Pedidos module (white surfaces), "dark" for Comandas (kitchen display). */
  variant?: "light" | "dark";
}

export function ResetDemoButton({ variant = "light" }: ResetDemoButtonProps) {
  const resetDemo = useOrderStore((s) => s.resetDemo);
  const [confirming, setConfirming] = useState(false);

  useEffect(() => {
    if (!confirming) return;
    const t = setTimeout(() => setConfirming(false), 3000);
    return () => clearTimeout(t);
  }, [confirming]);

  const base = "flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-[12px] font-semibold transition-colors";
  const theme =
    variant === "dark"
      ? confirming
        ? "bg-piolin-500/15 text-piolin-400"
        : "text-ink-500 hover:bg-ink-900 hover:text-ink-300"
      : confirming
        ? "bg-piolin-50 text-piolin-700"
        : "text-ink-400 hover:bg-ink-50 hover:text-ink-600";

  return (
    <button
      onClick={() => {
        if (confirming) {
          resetDemo();
          setConfirming(false);
        } else {
          setConfirming(true);
        }
      }}
      className={`${base} ${theme}`}
    >
      <RotateCcw className="h-3.5 w-3.5" strokeWidth={2} />
      {confirming ? "¿Seguro?" : "Restablecer demo"}
    </button>
  );
}
