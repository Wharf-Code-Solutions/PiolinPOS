import { useCallback, useState } from "react";

interface ToastEntry {
  id: string;
  message: string;
}

let counter = 0;

export function useToasts() {
  const [toasts, setToasts] = useState<ToastEntry[]>([]);

  const push = useCallback((message: string) => {
    const id = `t${Date.now()}-${counter++}`;
    setToasts((prev) => [...prev, { id, message }]);
  }, []);

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return { toasts, push, dismiss };
}
