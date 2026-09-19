import { CheckCircle2 } from "lucide-react";
import { useEffect, useState } from "react";

interface ToastProps {
  message: string;
  onDone: () => void;
  durationMs?: number;
}

/** A single, brief confirmation toast — used to acknowledge exactly what just happened. */
export function Toast({ message, onDone, durationMs = 2600 }: ToastProps) {
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const leaveTimer = setTimeout(() => setLeaving(true), durationMs - 250);
    const doneTimer = setTimeout(onDone, durationMs);
    return () => {
      clearTimeout(leaveTimer);
      clearTimeout(doneTimer);
    };
  }, [durationMs, onDone]);

  return (
    <div
      role="status"
      className={`flex items-center gap-2.5 rounded-lg bg-ink-950 px-4 py-3 text-white shadow-lg transition-all duration-250 ${
        leaving ? "opacity-0 translate-y-1" : "opacity-100 translate-y-0"
      }`}
    >
      <CheckCircle2 className="h-5 w-5 shrink-0 text-piolin-400" strokeWidth={2.25} />
      <span className="text-[15px] font-medium leading-snug">{message}</span>
    </div>
  );
}

interface ToastStackProps {
  toasts: { id: string; message: string }[];
  onDismiss: (id: string) => void;
}

export function ToastStack({ toasts, onDismiss }: ToastStackProps) {
  if (toasts.length === 0) return null;
  return (
    <div className="pointer-events-none fixed inset-x-0 top-4 z-50 flex flex-col items-center gap-2 px-4">
      {toasts.map((t) => (
        <div key={t.id} className="pointer-events-auto">
          <Toast message={t.message} onDone={() => onDismiss(t.id)} />
        </div>
      ))}
    </div>
  );
}
