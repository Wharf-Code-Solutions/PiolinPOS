import { useEffect, useState } from "react";
import { ProductGrid } from "../components/pos/ProductGrid";
import { CartPanel } from "../components/pos/CartPanel";
import { NotesModal } from "../components/pos/NotesModal";
import { SizeModal } from "../components/pos/SizeModal";
import { OptionModal } from "../components/pos/OptionModal";
import { VoiceOrderModal } from "../components/pos/VoiceOrderModal";
import { ConfirmOrderModal } from "../components/pos/ConfirmOrderModal";
import { RecentOrders } from "../components/orders/RecentOrders";
import { ResetDemoButton } from "../components/common/ResetDemoButton";
import { ToastStack } from "../components/common/Toast";
import { useToasts } from "../components/common/useToasts";
import { useOrderStore } from "../store/orderStore";
import type { CartLine } from "../components/pos/cartTypes";
import { mergeCartLines, newCartId } from "../components/pos/cartTypes";
import { hasSizeChoice, hasVariantChoice } from "../data/products";
import type { DiningOption, Product, ProductSize } from "../types";

export function OrdersPage() {
  const orders = useOrderStore((s) => s.orders);
  const nextId = useOrderStore((s) => s.nextId);
  const addOrder = useOrderStore((s) => s.addOrder);
  const lastEvent = useOrderStore((s) => s.lastEvent);

  const [lines, setLines] = useState<CartLine[]>([]);
  const [customerName, setCustomerName] = useState("");
  const [diningOption, setDiningOption] = useState<DiningOption>("Para llevar");
  const [justAddedId, setJustAddedId] = useState<string | null>(null);
  const [noteTargetId, setNoteTargetId] = useState<string | null>(null);
  const [sizeProduct, setSizeProduct] = useState<Product | null>(null);
  const [variantProduct, setVariantProduct] = useState<Product | null>(null);
  const [toppingPending, setToppingPending] = useState<{ product: Product; size: ProductSize } | null>(null);
  const [voiceOpen, setVoiceOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const { toasts, push, dismiss } = useToasts();

  const total = lines.reduce((sum, l) => sum + l.unitPrice * l.quantity, 0);

  useEffect(() => {
    if (lastEvent?.type === "ORDER_FINALIZED") {
      push(`Pedido #${lastEvent.orderId} finalizado en cocina`);
    }
  }, [lastEvent]); // eslint-disable-line react-hooks/exhaustive-deps

  function addLine(product: Product, size: ProductSize, variant?: string) {
    setLines((prev) =>
      mergeCartLines(prev, [
        {
          cartId: newCartId(),
          productId: product.id,
          key: product.key,
          name: product.name,
          unitPrice: size.price,
          quantity: 1,
          sizeLabel: product.sizes.length > 1 ? size.label : undefined,
          variant,
        },
      ]),
    );
    setJustAddedId(product.id);
    window.setTimeout(() => setJustAddedId((id) => (id === product.id ? null : id)), 350);
  }

  function handleAdd(product: Product) {
    if (hasVariantChoice(product)) {
      setVariantProduct(product);
      return;
    }
    if (hasSizeChoice(product)) {
      setSizeProduct(product);
      return;
    }
    addLine(product, product.sizes[0]);
  }

  function pickSize(size: ProductSize) {
    if (!sizeProduct) return;
    if (size.toppingOptions && size.toppingOptions.length > 0) {
      setToppingPending({ product: sizeProduct, size });
      setSizeProduct(null);
      return;
    }
    addLine(sizeProduct, size);
    setSizeProduct(null);
  }

  function pickVariant(flavor: string) {
    if (variantProduct) addLine(variantProduct, variantProduct.sizes[0], flavor);
    setVariantProduct(null);
  }

  function pickTopping(topping: string) {
    if (toppingPending) addLine(toppingPending.product, toppingPending.size, topping);
    setToppingPending(null);
  }

  function increment(cartId: string) {
    setLines((prev) => prev.map((l) => (l.cartId === cartId ? { ...l, quantity: l.quantity + 1 } : l)));
  }

  function decrement(cartId: string) {
    setLines((prev) =>
      prev
        .map((l) => (l.cartId === cartId ? { ...l, quantity: l.quantity - 1 } : l))
        .filter((l) => l.quantity > 0),
    );
  }

  function remove(cartId: string) {
    setLines((prev) => prev.filter((l) => l.cartId !== cartId));
  }

  function saveNote(value: string) {
    setLines((prev) =>
      prev.map((l) => (l.cartId === noteTargetId ? { ...l, notes: value || undefined } : l)),
    );
    setNoteTargetId(null);
  }

  function applyVoiceLines(voiceLines: CartLine[]) {
    setLines((prev) => mergeCartLines(prev, voiceLines));
    setVoiceOpen(false);
    push("Pedido agregado por voz ✓");
  }

  function handleConfirmSend() {
    const items = lines.map((l) => ({
      productId: l.productId,
      key: l.key,
      name: l.name,
      quantity: l.quantity,
      unitPrice: l.unitPrice,
      sizeLabel: l.sizeLabel,
      variant: l.variant,
      notes: l.notes,
    }));
    const order = addOrder(items, diningOption, customerName.trim() || undefined);
    setConfirmOpen(false);
    setLines([]);
    setCustomerName("");
    setDiningOption("Para llevar");
    push(`Pedido #${order.id} enviado a cocina`);
  }

  const noteTarget = lines.find((l) => l.cartId === noteTargetId);

  return (
    <div className="flex h-full min-h-0 flex-1 flex-col">
      <header className="flex items-center justify-between border-b border-ink-100 bg-white px-4 py-3.5 sm:px-6">
        <div>
          <h1 className="font-display text-[21px] font-semibold italic tracking-tight text-ink-950">
            PiolinPOS
          </h1>
          <p className="text-[11px] font-bold uppercase tracking-wide text-ink-300">
            Pedidos · POS / Ventanilla
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5 rounded-full bg-piolin-50 px-3.5 py-1.5 ring-1 ring-inset ring-piolin-100">
            <span className="text-[12.5px] font-semibold text-piolin-700">Pedido</span>
            <span className="font-display text-[15px] font-bold text-ink-950">#{nextId}</span>
          </div>
          <ResetDemoButton />
        </div>
      </header>

      <div className="flex min-h-0 flex-1 flex-col md:flex-row">
        <div className="min-h-0 min-w-0 flex-1">
          <ProductGrid onAdd={handleAdd} onVoiceOrder={() => setVoiceOpen(true)} justAddedId={justAddedId} />
        </div>
        <div className="min-h-0 min-w-0 border-t border-ink-100 md:w-[300px] md:shrink-0 md:border-l md:border-t-0 lg:w-[360px]">
          <CartPanel
            orderNumber={nextId}
            lines={lines}
            total={total}
            customerName={customerName}
            onCustomerNameChange={setCustomerName}
            diningOption={diningOption}
            onDiningOptionChange={setDiningOption}
            onIncrement={increment}
            onDecrement={decrement}
            onRemove={remove}
            onAddNote={setNoteTargetId}
            onConfirm={() => setConfirmOpen(true)}
          />
        </div>
      </div>

      <RecentOrders orders={orders} />

      {sizeProduct && (
        <SizeModal product={sizeProduct} onPick={pickSize} onClose={() => setSizeProduct(null)} />
      )}

      {variantProduct && (
        <OptionModal
          product={variantProduct}
          subtitle="Elige el sabor"
          options={variantProduct.variantOptions ?? []}
          onPick={pickVariant}
          onClose={() => setVariantProduct(null)}
        />
      )}

      {toppingPending && (
        <OptionModal
          product={toppingPending.product}
          subtitle="Elige el topping"
          options={toppingPending.size.toppingOptions ?? []}
          onPick={pickTopping}
          onClose={() => setToppingPending(null)}
        />
      )}

      {noteTarget && (
        <NotesModal
          productName={noteTarget.name}
          initialValue={noteTarget.notes ?? ""}
          onSave={saveNote}
          onClose={() => setNoteTargetId(null)}
        />
      )}

      {voiceOpen && <VoiceOrderModal onApply={applyVoiceLines} onClose={() => setVoiceOpen(false)} />}

      {confirmOpen && (
        <ConfirmOrderModal
          lines={lines}
          total={total}
          customerName={customerName}
          diningOption={diningOption}
          onBack={() => setConfirmOpen(false)}
          onConfirm={handleConfirmSend}
        />
      )}

      <ToastStack toasts={toasts} onDismiss={dismiss} />
    </div>
  );
}
