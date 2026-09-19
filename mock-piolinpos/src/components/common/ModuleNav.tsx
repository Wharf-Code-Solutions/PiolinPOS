import { ClipboardList, ChefHat } from "lucide-react";
import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";

const items = [
  {
    to: "/pedidos",
    label: "PEDIDOS",
    sub: "POS / Ventanilla",
    icon: ClipboardList,
  },
  {
    to: "/comandas",
    label: "COMANDAS",
    sub: "Cocina",
    icon: ChefHat,
  },
];

/**
 * Vertical module rail. In real deployment each tablet lives permanently on one
 * module — this switcher exists so the demo can show both from one device.
 */
export function ModuleNav({ footer }: { footer?: ReactNode }) {
  return (
    <nav className="flex h-full w-[84px] shrink-0 flex-col items-center gap-1 border-r border-ink-200 bg-white py-4 sm:w-[96px]">
      <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-md bg-ink-950 text-[13px] font-bold tracking-tight text-piolin-400">
        P
      </div>
      {items.map(({ to, label, sub, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          className={({ isActive }) =>
            `flex w-[76px] flex-col items-center gap-1 rounded-lg px-1.5 py-2.5 text-center transition-colors sm:w-[86px] ${
              isActive
                ? "bg-piolin-50 text-piolin-700"
                : "text-ink-500 hover:bg-ink-50 hover:text-ink-700"
            }`
          }
        >
          {({ isActive }) => (
            <>
              <Icon className="h-5 w-5" strokeWidth={isActive ? 2.4 : 2} />
              <span className="text-[10.5px] font-bold leading-tight tracking-wide">{label}</span>
              <span className="text-[8.5px] font-medium leading-tight text-ink-400">{sub}</span>
            </>
          )}
        </NavLink>
      ))}
      {footer}
    </nav>
  );
}
