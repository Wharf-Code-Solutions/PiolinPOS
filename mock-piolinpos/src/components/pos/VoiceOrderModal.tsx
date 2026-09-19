import { useRef, useState } from "react";
import { Mic, X, AlertTriangle } from "lucide-react";
import { Sheet } from "../common/Sheet";
import { useVoiceRecorder } from "../../hooks/useVoiceRecorder";
import { PRODUCTS, INGREDIENTE_LABELS } from "../../data/products";
import type { CartLine } from "./cartTypes";
import { newCartId } from "./cartTypes";

interface VoiceOrderModalProps {
  onApply: (lines: CartLine[]) => void;
  onClose: () => void;
}

interface LineaVoz {
  id_producto: number;
  cantidad: number;
  selecciones: { ingredientes: string[]; modo: string | null };
  quitar: string[];
  fragmento: string;
  modo_por_defecto: boolean;
  incompleta: boolean;
  error: boolean;
  unitPrice: number;
  subtotal: number;
}

interface NoReconocido {
  texto: string;
  cantidad: number;
}

interface RespuestaVoz {
  transcripcion: string;
  lineas: LineaVoz[];
  no_reconocidos: NoReconocido[];
  total: number;
  error?: string;
}

type Stage = "idle" | "grabando" | "procesando" | "revision" | "error";

function capitalizar(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function lineaANotas(linea: LineaVoz, esSuperTorta: boolean): string | undefined {
  const partes: string[] = [];
  if (esSuperTorta) {
    const modoLabel = capitalizar(linea.selecciones.modo ?? "mitad y mitad");
    partes.push(linea.modo_por_defecto ? `${modoLabel} (por defecto)` : modoLabel);
  }
  if (linea.quitar.length > 0) partes.push(`Sin ${linea.quitar.join(", ")}`);
  return partes.length > 0 ? partes.join(" · ") : undefined;
}

export function VoiceOrderModal({ onApply, onClose }: VoiceOrderModalProps) {
  const { error: recError, start, stop } = useVoiceRecorder();
  const [stage, setStage] = useState<Stage>("idle");
  const [respuesta, setRespuesta] = useState<RespuestaVoz | null>(null);
  const [descartados, setDescartados] = useState<Set<number>>(new Set());
  const [cantidades, setCantidades] = useState<Record<number, number>>({});
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const pressActive = useRef(false);

  async function handlePressStart() {
    if (pressActive.current) return;
    pressActive.current = true;
    setErrorMsg(null);
    setStage("grabando");
    await start();
  }

  async function handlePressEnd() {
    if (!pressActive.current) return;
    pressActive.current = false;
    setStage("procesando");
    const grabacion = await stop();
    if (!grabacion) {
      setStage("idle");
      return;
    }
    try {
      const form = new FormData();
      const ext = grabacion.mimeType.includes("webm")
        ? "webm"
        : grabacion.mimeType.includes("mp4")
          ? "mp4"
          : "ogg";
      form.append("audio", grabacion.blob, `pedido.${ext}`);

      const res = await fetch("/voz", { method: "POST", body: form });
      const data: RespuestaVoz = await res.json();
      if (!res.ok) throw new Error(data.error ?? "No se pudo procesar el audio.");

      setRespuesta(data);
      setDescartados(new Set());
      setCantidades(Object.fromEntries(data.lineas.map((linea, i) => [i, linea.cantidad])));
      setStage("revision");
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : "No se pudo procesar el audio.");
      setStage("error");
    }
  }

  function reintentar() {
    setRespuesta(null);
    setErrorMsg(null);
    setStage("idle");
  }

  function agregarAlPedido() {
    if (!respuesta) return;
    const lines: CartLine[] = respuesta.lineas
      .map((linea, i) => ({ linea, i }))
      .filter(({ linea, i }) => !linea.error && !descartados.has(i))
      .map(({ linea, i }) => {
        const producto = PRODUCTS.find((p) => p.id === linea.id_producto);
        const cantidad = cantidades[i] ?? linea.cantidad;
        const variant =
          linea.selecciones.ingredientes.length === 2
            ? linea.selecciones.ingredientes.map((ing) => INGREDIENTE_LABELS[ing] ?? capitalizar(ing)).join(" + ")
            : undefined;
        return {
          cartId: newCartId(),
          productId: linea.id_producto,
          key: producto?.key ?? "?",
          name: producto?.name ?? "Producto",
          unitPrice: linea.unitPrice,
          quantity: cantidad,
          variant,
          notes: lineaANotas(linea, !!producto?.isSuperTorta),
        };
      });
    onApply(lines);
  }

  const totalRevision = (respuesta?.lineas ?? []).reduce((sum, linea, i) => {
    if (descartados.has(i) || linea.error) return sum;
    return sum + linea.unitPrice * (cantidades[i] ?? linea.cantidad);
  }, 0);
  const hayAlgoParaAgregar = (respuesta?.lineas ?? []).some((linea, i) => !descartados.has(i) && !linea.error);

  return (
    <Sheet onClose={onClose} wide>
      <div className="flex items-center justify-between px-5 pt-5">
        <h3 className="text-[17px] font-bold text-ink-900">Tomar pedido por voz</h3>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>

      {stage === "idle" && (
        <div className="flex flex-col items-center gap-4 px-5 pb-8 pt-6 text-center">
          <p className="text-[14px] text-ink-500">Mantén presionado el micrófono y dicta el pedido del cliente.</p>
          <button
            onMouseDown={handlePressStart}
            onMouseUp={handlePressEnd}
            onMouseLeave={() => {
              if (pressActive.current) handlePressEnd();
            }}
            onTouchStart={(e) => {
              e.preventDefault();
              handlePressStart();
            }}
            onTouchEnd={(e) => {
              e.preventDefault();
              handlePressEnd();
            }}
            className="flex h-24 w-24 items-center justify-center rounded-full bg-piolin-600 active:scale-95"
          >
            <Mic className="h-9 w-9 text-white" strokeWidth={2} />
          </button>
          {(recError || errorMsg) && (
            <p className="rounded-lg bg-status-late-bg px-3.5 py-2.5 text-[13px] font-semibold text-status-late">
              {recError ?? errorMsg}
            </p>
          )}
        </div>
      )}

      {stage === "grabando" && (
        <div className="flex flex-col items-center gap-4 px-5 pb-8 pt-6 text-center">
          <p className="text-[13px] font-bold uppercase tracking-wide text-ink-500">Escuchando…</p>
          <button
            onMouseUp={handlePressEnd}
            onTouchEnd={(e) => {
              e.preventDefault();
              handlePressEnd();
            }}
            className="flex h-24 w-24 animate-pulse items-center justify-center rounded-full bg-piolin-600"
          >
            <Mic className="h-9 w-9 text-white" strokeWidth={2} />
          </button>
          <p className="text-[13.5px] font-semibold text-ink-500">Suelta para procesar</p>
        </div>
      )}

      {stage === "procesando" && (
        <div className="flex flex-col items-center gap-3 px-5 pb-10 pt-8 text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-ink-200 border-t-piolin-600" />
          <p className="text-[14px] font-semibold text-ink-500">Transcribiendo y armando el pedido…</p>
        </div>
      )}

      {stage === "error" && (
        <div className="px-5 pb-6 pt-4">
          <p className="mb-5 rounded-lg bg-status-late-bg px-4 py-3.5 text-[14px] font-semibold text-status-late">
            {errorMsg}
          </p>
          <button
            onClick={reintentar}
            className="w-full rounded-xl bg-piolin-600 py-3.5 text-[15px] font-bold text-white active:scale-[0.98]"
          >
            Reintentar
          </button>
        </div>
      )}

      {stage === "revision" && respuesta && (
        <div className="px-5 pb-5 pt-3">
          <p className="mb-1 text-[12px] font-bold uppercase tracking-wide text-ink-500">Se escuchó</p>
          <p className="mb-4 rounded-lg bg-ink-50 px-4 py-3 text-[15px] font-medium italic text-ink-800">
            “{respuesta.transcripcion}”
          </p>

          <div className="mb-4 flex max-h-[38vh] flex-col gap-2 overflow-y-auto">
            {respuesta.lineas.map((linea, i) => {
              if (descartados.has(i)) return null;
              const producto = PRODUCTS.find((p) => p.id === linea.id_producto);
              const cantidad = cantidades[i] ?? linea.cantidad;
              return (
                <div
                  key={i}
                  className={`rounded-lg border p-3 ${
                    linea.error
                      ? "border-status-late bg-status-late-bg"
                      : linea.incompleta || linea.modo_por_defecto
                        ? "border-piolin-300 bg-piolin-50"
                        : "border-ink-100 bg-ink-50/60"
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="truncate text-[15px] font-semibold text-ink-900">
                        {producto?.name ?? "Producto no identificado"}
                      </p>
                      <p className="text-[12.5px] text-ink-500">“{linea.fragmento}”</p>
                      {linea.selecciones.ingredientes.length > 0 && (
                        <p className="mt-0.5 text-[13px] font-medium text-ink-600">
                          {linea.selecciones.ingredientes
                            .map((ing) => INGREDIENTE_LABELS[ing] ?? capitalizar(ing))
                            .join(" + ")}
                        </p>
                      )}
                      {linea.error && (
                        <p className="mt-1 flex items-center gap-1 text-[12.5px] font-bold text-status-late">
                          <AlertTriangle className="h-3.5 w-3.5" />
                          {linea.selecciones.ingredientes.length > 2
                            ? "Más de 2 ingredientes — revisa manualmente"
                            : "No se pudo validar este producto"}
                        </p>
                      )}
                      {!linea.error && linea.modo_por_defecto && (
                        <p className="mt-1 text-[12px] font-bold uppercase tracking-wide text-piolin-700">
                          Modo por defecto: {linea.selecciones.modo}
                        </p>
                      )}
                      {linea.quitar.length > 0 && (
                        <p className="mt-1 inline-block rounded bg-piolin-100 px-1.5 py-0.5 text-[12px] font-semibold uppercase tracking-wide text-piolin-700">
                          Sin {linea.quitar.join(", ")}
                        </p>
                      )}
                    </div>
                    <button
                      onClick={() => setDescartados((prev) => new Set(prev).add(i))}
                      aria-label="Quitar línea"
                      className="shrink-0 rounded-md p-1.5 text-ink-400 active:bg-ink-100"
                    >
                      <X className="h-4 w-4" />
                    </button>
                  </div>
                  {!linea.error && (
                    <div className="mt-2 flex items-center gap-2">
                      <div className="flex items-center gap-1 rounded-lg bg-white ring-1 ring-inset ring-ink-200">
                        <button
                          onClick={() =>
                            setCantidades((prev) => ({ ...prev, [i]: Math.max(1, cantidad - 1) }))
                          }
                          className="flex h-8 w-8 items-center justify-center text-ink-600 active:bg-ink-50"
                        >
                          −
                        </button>
                        <span className="w-5 text-center text-[14px] font-bold tabular-nums text-ink-900">
                          {cantidad}
                        </span>
                        <button
                          onClick={() => setCantidades((prev) => ({ ...prev, [i]: cantidad + 1 }))}
                          className="flex h-8 w-8 items-center justify-center text-ink-600 active:bg-ink-50"
                        >
                          +
                        </button>
                      </div>
                      <span className="text-[13px] text-ink-500">
                        ${linea.unitPrice} c/u · ${linea.unitPrice * cantidad}
                      </span>
                    </div>
                  )}
                </div>
              );
            })}

            {respuesta.no_reconocidos.length > 0 && (
              <div className="rounded-lg border border-dashed border-ink-200 p-3">
                <p className="mb-1.5 text-[12px] font-bold uppercase tracking-wide text-ink-500">
                  No reconocidos
                </p>
                <div className="flex flex-wrap gap-1.5">
                  {respuesta.no_reconocidos.map((nr, i) => (
                    <span
                      key={i}
                      className="rounded-full bg-ink-100 px-3 py-1 text-[12.5px] font-semibold text-ink-600"
                    >
                      {nr.cantidad} × {nr.texto}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="mb-4 flex items-baseline justify-between border-t border-ink-100 pt-3">
            <span className="text-[14px] font-semibold text-ink-600">Total</span>
            <span className="font-display text-[22px] font-semibold text-ink-950">${totalRevision}</span>
          </div>

          <div className="flex gap-3">
            <button
              onClick={reintentar}
              className="flex-1 rounded-xl py-3.5 text-[15px] font-semibold text-ink-600 ring-1 ring-inset ring-ink-200 active:bg-ink-50"
            >
              Reintentar
            </button>
            <button
              onClick={agregarAlPedido}
              disabled={!hayAlgoParaAgregar}
              className="flex-1 rounded-xl bg-piolin-600 py-3.5 text-[15px] font-bold text-white active:scale-[0.98] disabled:cursor-not-allowed disabled:bg-ink-200 disabled:text-ink-400"
            >
              Agregar al pedido
            </button>
          </div>
        </div>
      )}
    </Sheet>
  );
}
