import { useEffect } from "react";
import { HashRouter, Link, Route, Routes } from "react-router-dom";
import { ClipboardList, ChefHat } from "lucide-react";
import { OrdersPage } from "./pages/OrdersPage";
import { ComandasPage } from "./pages/ComandasPage";
import { initOrderStoreSync } from "./store/orderStore";

/**
 * Landing screen for setting up a device the first time. Each tablet is meant to
 * be pinned (bookmark / kiosk shortcut) to /#/pedidos or /#/comandas directly —
 * neither module offers a way to jump to the other, by design: Pedidos is the
 * operator's POS, Comandas is the kitchen display, and they don't cross.
 */
function DeviceSetupPage() {
  return (
    <div className="flex h-svh w-full flex-col items-center justify-center gap-8 bg-ink-50 px-6 text-center">
      <div>
        <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-ink-950 text-[16px] font-bold tracking-tight text-piolin-400">
          P
        </div>
        <h1 className="font-display text-[22px] font-semibold italic tracking-tight text-ink-950">
          PiolinPOS
        </h1>
        <p className="mt-1 text-[14px] text-ink-500">
          Elige qué es este dispositivo. Cada módulo vive en su propia pantalla.
        </p>
      </div>

      <div className="flex w-full max-w-sm flex-col gap-3">
        <Link
          to="/pedidos"
          className="flex items-center gap-4 rounded-xl border border-ink-200 bg-white p-5 text-left shadow-sm active:bg-ink-50"
        >
          <ClipboardList className="h-8 w-8 shrink-0 text-piolin-600" strokeWidth={1.8} />
          <div>
            <p className="text-[16px] font-bold text-ink-900">Pedidos</p>
            <p className="text-[13px] text-ink-500">POS / Ventanilla</p>
          </div>
        </Link>
        <Link
          to="/comandas"
          className="flex items-center gap-4 rounded-xl border border-ink-200 bg-white p-5 text-left shadow-sm active:bg-ink-50"
        >
          <ChefHat className="h-8 w-8 shrink-0 text-piolin-600" strokeWidth={1.8} />
          <div>
            <p className="text-[16px] font-bold text-ink-900">Comandas</p>
            <p className="text-[13px] text-ink-500">Cocina</p>
          </div>
        </Link>
      </div>
    </div>
  );
}

function App() {
  useEffect(() => initOrderStoreSync(), []);

  return (
    <HashRouter>
      <Routes>
        <Route path="/" element={<DeviceSetupPage />} />
        <Route path="/pos" element={<OrdersPage />} />
        <Route path="/pedidos" element={<OrdersPage />} />
        <Route path="/comandas" element={<ComandasPage />} />
        <Route path="*" element={<DeviceSetupPage />} />
      </Routes>
    </HashRouter>
  );
}

export default App;
