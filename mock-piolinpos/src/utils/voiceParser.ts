import { PRODUCTS } from "../data/products";
import type { OrderItem, SizeLabel } from "../types";

/** Lowercase + strip accents, so matching survives speech-recognition spelling variance. */
function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

const NUMBER_WORDS: Record<string, number> = {
  un: 1,
  una: 1,
  uno: 1,
  dos: 2,
  tres: 3,
  cuatro: 4,
  cinco: 5,
  seis: 6,
};

// Alias phrases -> product id, longest/most-specific first so specific phrases win over generic ones.
const PRODUCT_ALIASES: { pattern: string; id: string }[] = [
  { pattern: "torta de jamon con queso amarillo", id: "torta-jamon-amarillo" },
  { pattern: "torta de jamon con queso hebra", id: "torta-jamon-hebra" },
  { pattern: "torta de jamon amarillo", id: "torta-jamon-amarillo" },
  { pattern: "torta de jamon hebra", id: "torta-jamon-hebra" },
  { pattern: "cuerno de 4 quesos", id: "cuerno-4-quesos" },
  { pattern: "cuerno de cuatro quesos", id: "cuerno-4-quesos" },
  { pattern: "cuerno", id: "cuerno-4-quesos" },
  { pattern: "torta de jamon", id: "torta-jamon-amarillo" },
  { pattern: "promo taco", id: "promo-tacos" },
  { pattern: "taco", id: "promo-tacos" },
  { pattern: "hamburguesa", id: "hamburguesa" },
  { pattern: "coca-cola", id: "coca-600" },
  { pattern: "coca cola", id: "coca-600" },
  { pattern: "coca", id: "coca-600" },
  { pattern: "pepsi", id: "pepsi-600" },
  { pattern: "agua mineral", id: "agua-mineral" },
  { pattern: "agua natural", id: "agua-natural" },
  { pattern: "agua", id: "agua-natural" },
  { pattern: "papas", id: "papas" },
  { pattern: "galletas", id: "galletas" },
  { pattern: "sabritas", id: "sabritas" },
];

const NOTE_PHRASES: { pattern: string; label: string }[] = [
  { pattern: "sin cebolla", label: "Sin cebolla" },
  { pattern: "sin chile", label: "Sin chile" },
  { pattern: "bien caliente", label: "Bien caliente" },
  { pattern: "extra salsa", label: "Extra salsa" },
];

const SIZE_WORDS: { pattern: string; label: SizeLabel }[] = [
  { pattern: "super", label: "Súper" },
  { pattern: "grande", label: "Súper" },
  { pattern: "sencillo", label: "Sencillo" },
  { pattern: "sencilla", label: "Sencillo" },
  { pattern: "chica", label: "Sencillo" },
];

const QTY_WINDOW = 15;
const SIZE_WINDOW = 22;

/**
 * Best-effort interpreter for spoken orders. Takes a transcript — either a
 * real Web Speech API result or one of the canned demo phrases — and maps it
 * to cart items: product, quantity, size (Sencillo/Súper when the product
 * offers a choice) and shared notes (only applied to Tortas, matching what
 * NotesModal offers). Not a full NLU stack: relies on keyword/alias matching,
 * so unusual phrasing may be missed — the operator can always fix the cart
 * afterward.
 */
// Singularize the handful of plural nouns operators actually say, so "dos
// tortas de jamón" still matches the singular alias patterns below.
const PLURALS: [RegExp, string][] = [
  [/\btortas\b/g, "torta"],
  [/\baguas\b/g, "agua"],
  [/\bcocas\b/g, "coca"],
  [/\bpepsis\b/g, "pepsi"],
  [/\bcuernos\b/g, "cuerno"],
];

export function parseVoiceOrder(transcript: string): OrderItem[] {
  let text = normalize(transcript);
  for (const [pattern, replacement] of PLURALS) text = text.replace(pattern, replacement);
  const globalNotes = NOTE_PHRASES.filter((n) => text.includes(n.pattern)).map((n) => n.label);
  const notesLabel = globalNotes.length > 0 ? globalNotes.join(", ") : undefined;

  const items: OrderItem[] = [];
  const consumed = new Set<number>();

  for (const alias of PRODUCT_ALIASES) {
    let searchFrom = 0;
    while (true) {
      const idx = text.indexOf(alias.pattern, searchFrom);
      if (idx === -1) break;
      searchFrom = idx + alias.pattern.length;

      // Skip if this span overlaps a longer alias already matched.
      let overlaps = false;
      for (let i = idx; i < idx + alias.pattern.length; i++) {
        if (consumed.has(i)) overlaps = true;
      }
      if (overlaps) continue;
      for (let i = idx; i < idx + alias.pattern.length; i++) consumed.add(i);

      const product = PRODUCTS.find((p) => p.id === alias.id);
      if (!product) continue;

      // Quantity: look for a number word/digit just before the match.
      const before = text.slice(Math.max(0, idx - QTY_WINDOW), idx).trim();
      let qty = 1;
      for (const w of before.split(/\s+/)) {
        const clean = w.replace(/[^a-z0-9]/gi, "");
        if (NUMBER_WORDS[clean]) qty = NUMBER_WORDS[clean];
        else if (/^\d+$/.test(clean)) qty = parseInt(clean, 10);
      }

      // Size: look for "súper"/"sencillo" (or synonyms) shortly after the match.
      let sizeLabel: SizeLabel | undefined = product.sizes.length > 1 ? "Sencillo" : undefined;
      if (product.sizes.length > 1) {
        const after = text.slice(idx + alias.pattern.length, idx + alias.pattern.length + SIZE_WINDOW);
        const sizeMatch = SIZE_WORDS.find((s) => after.includes(s.pattern));
        if (sizeMatch) sizeLabel = sizeMatch.label;
      }
      const sizeEntry = product.sizes.find((s) => s.label === sizeLabel) ?? product.sizes[0];
      const applyNotes = product.category === "Tortas" ? notesLabel : undefined;

      // Flavor (taco) or topping (burger Súper) — required whenever the product/size
      // offers one; default to the first option when the transcript doesn't name it.
      const after = text.slice(idx + alias.pattern.length, idx + alias.pattern.length + SIZE_WINDOW);
      let variant: string | undefined;
      if (product.variantOptions && product.variantOptions.length > 0) {
        const found = product.variantOptions.find((opt) => after.includes(normalize(opt)));
        variant = found ?? product.variantOptions[0];
      } else if (sizeEntry.toppingOptions && sizeEntry.toppingOptions.length > 0) {
        const found = sizeEntry.toppingOptions.find((opt) => after.includes(normalize(opt)));
        variant = found ?? sizeEntry.toppingOptions[0];
      }

      const existing = items.find(
        (it) =>
          it.productId === product.id &&
          it.notes === applyNotes &&
          it.sizeLabel === sizeLabel &&
          it.variant === variant,
      );
      if (existing) {
        existing.quantity += qty;
      } else {
        items.push({
          productId: product.id,
          key: product.key,
          name: product.name,
          quantity: qty,
          unitPrice: sizeEntry.price,
          sizeLabel: product.sizes.length > 1 ? sizeLabel : undefined,
          variant,
          notes: applyNotes,
        });
      }
    }
  }

  return items;
}

export const VOICE_DEMO_PHRASES = [
  "Dos tortas de jamón amarillo súper, una Coca y un agua",
  "Una promo tacos de carnitas y dos aguas",
  "Una hamburguesa súper con tocino y una Coca",
];
