const GROQ_TRANSCRIPTION_URL = "https://api.groq.com/openai/v1/audio/transcriptions";

function promptDeCatalogo(catalogo) {
  const nombres = catalogo.flatMap((p) => [p.nombre, ...(p.sinonimos ?? [])]);
  return `Pedido hablado en una tienda mexicana de tacos y tortas. Vocabulario esperado: ${nombres.join(", ")}.`;
}

function extensionPara(mimeType) {
  if (mimeType.includes("webm")) return "webm";
  if (mimeType.includes("mp4")) return "mp4";
  if (mimeType.includes("ogg")) return "ogg";
  return "wav";
}

/**
 * transcribir(audio, mimeType) -> texto
 *
 * Capa reemplazable: hoy usa Whisper-large-v3-turbo en Groq (rápido y barato).
 * Cambiar de proveedor (Whisper local, OpenAI, etc.) solo implica reescribir
 * esta función — nada más del backend depende de Groq directamente.
 */
export async function transcribir(audioBuffer, mimeType, catalogo) {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("Falta GROQ_API_KEY en server/.env");

  const form = new FormData();
  form.append("file", new Blob([audioBuffer], { type: mimeType }), `audio.${extensionPara(mimeType)}`);
  form.append("model", "whisper-large-v3-turbo");
  form.append("language", "es");
  form.append("temperature", "0");
  form.append("prompt", promptDeCatalogo(catalogo));

  const res = await fetch(GROQ_TRANSCRIPTION_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: form,
  });

  if (!res.ok) {
    const detalle = await res.text();
    throw new Error(`Groq Whisper respondió ${res.status}: ${detalle}`);
  }

  const data = await res.json();
  return (data.text ?? "").trim();
}
