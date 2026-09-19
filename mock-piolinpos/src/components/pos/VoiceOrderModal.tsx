import { useEffect, useState } from "react";
import { Mic, Square, X } from "lucide-react";
import { Sheet } from "../common/Sheet";
import { VOICE_DEMO_PHRASES, parseVoiceOrder } from "../../utils/voiceParser";
import { useSpeechRecognition } from "../../hooks/useSpeechRecognition";
import type { CartLine } from "./cartTypes";
import { newCartId } from "./cartTypes";

interface VoiceOrderModalProps {
  onApply: (lines: CartLine[]) => void;
  onClose: () => void;
}

type Stage = "idle" | "listening" | "ready";

export function VoiceOrderModal({ onApply, onClose }: VoiceOrderModalProps) {
  const { supported, listening, transcript, error, start, stop, reset } = useSpeechRecognition();
  const [stage, setStage] = useState<Stage>("idle");
  const [finalPhrase, setFinalPhrase] = useState("");

  // When the recognizer stops (silence detected, or the operator tapped stop),
  // hand off whatever it heard to the "ready" review step.
  useEffect(() => {
    if (stage !== "listening" || listening) return;
    if (transcript.trim()) {
      setFinalPhrase(transcript.trim());
      setStage("ready");
    } else {
      setStage("idle");
    }
  }, [listening, stage, transcript]);

  function startListening() {
    reset();
    setStage("listening");
    start();
  }

  function pickPhrase(p: string) {
    setFinalPhrase(p);
    setStage("ready");
  }

  function tryAgain() {
    setFinalPhrase("");
    setStage("idle");
  }

  function process() {
    const items = parseVoiceOrder(finalPhrase);
    const lines: CartLine[] = items.map((it) => ({
      cartId: newCartId(),
      productId: it.productId,
      key: it.key,
      name: it.name,
      unitPrice: it.unitPrice,
      quantity: it.quantity,
      sizeLabel: it.sizeLabel,
      notes: it.notes,
    }));
    onApply(lines);
  }

  return (
    <Sheet onClose={onClose} wide>
      <div className="flex items-center justify-between px-5 pt-5">
        <h3 className="text-[17px] font-bold text-ink-900">Tomar pedido por voz</h3>
        <button onClick={onClose} aria-label="Cerrar" className="rounded-md p-1.5 text-ink-400 active:bg-ink-100">
          <X className="h-5 w-5" />
        </button>
      </div>

      {stage === "idle" && (
        <div className="px-5 pb-5 pt-4">
          {supported ? (
            <>
              <p className="mb-4 text-[14px] text-ink-500">
                Toca el micrófono y dicta el pedido del cliente.
              </p>
              <button
                onClick={startListening}
                className="mb-5 flex w-full flex-col items-center gap-3 rounded-xl border border-dashed border-ink-200 py-8 active:bg-ink-50"
              >
                <span className="flex h-16 w-16 items-center justify-center rounded-full bg-piolin-600">
                  <Mic className="h-7 w-7 text-white" strokeWidth={2} />
                </span>
                <span className="text-[15px] font-bold text-ink-900">Comenzar a escuchar</span>
              </button>
              {error && (
                <p className="mb-4 rounded-lg bg-status-late-bg px-3.5 py-2.5 text-[13px] font-semibold text-status-late">
                  {error}
                </p>
              )}
              <p className="mb-2 text-[12px] font-bold uppercase tracking-wide text-ink-400">
                O elige un ejemplo
              </p>
            </>
          ) : (
            <p className="mb-4 rounded-lg bg-ink-50 px-4 py-3 text-[13.5px] text-ink-600">
              Este navegador no soporta reconocimiento de voz. Elige un ejemplo para simular la captura.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {VOICE_DEMO_PHRASES.map((p) => (
              <button
                key={p}
                onClick={() => pickPhrase(p)}
                className="rounded-lg border border-ink-200 px-4 py-3.5 text-left text-[15px] font-medium text-ink-800 active:bg-ink-50"
              >
                “{p}”
              </button>
            ))}
          </div>
        </div>
      )}

      {stage === "listening" && (
        <div className="flex flex-col items-center gap-4 px-5 pb-8 pt-4 text-center">
          <p className="text-[13px] font-bold uppercase tracking-wide text-ink-500">Escuchando…</p>
          <button
            onClick={stop}
            aria-label="Detener y procesar"
            className="flex h-20 w-20 items-center justify-center rounded-full bg-piolin-100"
          >
            <span className="flex h-20 w-20 animate-pulse items-center justify-center rounded-full">
              <Square className="h-8 w-8 fill-piolin-600 text-piolin-600" strokeWidth={0} />
            </span>
          </button>
          <p className="min-h-[24px] px-4 text-[16px] font-medium italic text-ink-700">
            {transcript || "…"}
          </p>
          <button
            onClick={stop}
            className="text-[13.5px] font-semibold text-ink-500 underline underline-offset-2"
          >
            Terminar y procesar
          </button>
        </div>
      )}

      {stage === "ready" && (
        <div className="px-5 pb-5 pt-4">
          <p className="mb-2 text-[13px] font-bold uppercase tracking-wide text-ink-500">Se escuchó:</p>
          <p className="mb-5 rounded-lg bg-ink-50 px-4 py-3.5 text-[16px] font-medium italic text-ink-800">
            “{finalPhrase}”
          </p>
          <div className="flex gap-3">
            <button
              onClick={tryAgain}
              className="flex-1 rounded-xl py-3.5 text-[15px] font-semibold text-ink-600 ring-1 ring-inset ring-ink-200 active:bg-ink-50"
            >
              Reintentar
            </button>
            <button
              onClick={process}
              className="flex-1 rounded-xl bg-piolin-600 py-3.5 text-[15px] font-bold text-white active:scale-[0.98]"
            >
              Procesar pedido
            </button>
          </div>
        </div>
      )}
    </Sheet>
  );
}
