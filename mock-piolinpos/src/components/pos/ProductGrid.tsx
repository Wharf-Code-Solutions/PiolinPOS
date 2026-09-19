import { useState } from "react";
import { Mic } from "lucide-react";
import { CATEGORIES, PRODUCTS, hasSizeChoice } from "../../data/products";
import type { Product, ProductCategory } from "../../types";

interface ProductGridProps {
  onAdd: (product: Product) => void;
  onVoiceOrder: () => void;
  justAddedId: string | null;
}

const CATEGORY_ACCENT: Record<ProductCategory, string> = {
  Tortas: "border-l-cat-tortas",
  Bebidas: "border-l-cat-bebidas",
  Snacks: "border-l-cat-snacks",
};

export function ProductGrid({ onAdd, onVoiceOrder, justAddedId }: ProductGridProps) {
  const [category, setCategory] = useState<Product["category"]>(CATEGORIES[0]);
  const products = PRODUCTS.filter((p) => p.category === category);

  return (
    <div className="flex h-full flex-col">
      <div className="flex gap-2 overflow-x-auto px-4 pb-3 pt-4 sm:px-6">
        {CATEGORIES.map((cat) => (
          <button
            key={cat}
            onClick={() => setCategory(cat)}
            className={`shrink-0 rounded-full px-5 py-2.5 text-[15px] font-semibold transition-colors ${
              category === cat
                ? "bg-ink-950 text-white"
                : "bg-white text-ink-600 ring-1 ring-inset ring-ink-100"
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="grid flex-1 auto-rows-min grid-cols-2 gap-3 overflow-y-auto px-4 pb-6 sm:gap-4 sm:px-6 lg:grid-cols-3">
        {products.map((product) => {
          const multiSize = hasSizeChoice(product);
          const minPrice = Math.min(...product.sizes.map((s) => s.price));
          return (
            <button
              key={product.id}
              onClick={() => onAdd(product)}
              className={`group relative flex min-h-[112px] flex-col justify-between rounded-xl border border-l-4 bg-white p-4 text-left shadow-sm transition-all active:scale-[0.97] active:shadow-none sm:min-h-[132px] sm:p-5 ${
                CATEGORY_ACCENT[product.category]
              } ${
                justAddedId === product.id
                  ? "border-piolin-500 border-l-piolin-500 ring-2 ring-piolin-100"
                  : "border-ink-100"
              }`}
            >
              <div>
                <span className="mb-1.5 inline-block rounded bg-ink-50 px-1.5 py-0.5 text-[11px] font-extrabold uppercase tracking-wide text-ink-400">
                  {product.key}
                </span>
                <p className="text-[16px] font-bold leading-snug text-ink-900 sm:text-[17px]">
                  {product.name}
                </p>
              </div>
              <span className="font-display text-[18px] font-semibold text-ink-600 sm:text-[20px]">
                {multiSize ? `Desde $${minPrice}` : `$${minPrice}`}
              </span>
            </button>
          );
        })}

        {/* Voice order — an equally-weighted tile, not an afterthought button */}
        <button
          onClick={onVoiceOrder}
          className="flex min-h-[112px] flex-col items-start justify-center gap-2.5 rounded-xl bg-ink-950 p-4 text-left transition-transform active:scale-[0.97] sm:min-h-[132px] sm:p-5"
        >
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-ink-800">
            <Mic className="h-4 w-4 text-piolin-400" strokeWidth={2.2} />
          </span>
          <span className="text-[14.5px] font-bold leading-snug text-white">
            Tomar pedido
            <br />
            por voz
          </span>
        </button>
      </div>
    </div>
  );
}
