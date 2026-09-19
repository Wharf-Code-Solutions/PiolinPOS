const GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions";

const NUMBER_WORDS = {
  un: 1, una: 1, uno: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5,
  seis: 6, siete: 7, ocho: 8, nueve: 9, diez: 10,
};

const INGREDIENTES_TORTA = ["milanesa", "jamon", "pierna"];

// Heurística de la capa de reglas: solo detecta un puñado de productos
// comunes fuera de catálogo para poder poblar "no_reconocidos" sin backend
// de IA. Cualquier otra cosa fuera de este catálogo cae al LLM (segunda capa).
const NO_CATALOGO_CONOCIDOS = ["cerveza", "quesadilla", "burrito", "pizza", "hot dog", "elote", "torta ahogada"];

// Deliberadamente NO incluye números: un número que el parser no logró
// enganchar a ningún producto (p. ej. una segunda cantidad suelta como en
// "cinco de pastor, dos sin cebolla") debe bajar la confianza, no ocultarse.
const PALABRAS_IGNORABLES = new Set([
  "y", "de", "del", "la", "el", "los", "las", "con", "para", "por",
  "favor", "gracias", "dame", "deme", "quiero", "llevar", "aqui", "aquí",
  "eh", "este", "esta", "osea", "o", "sea", "pues", "mejor", "porfa",
  // Sustantivos genéricos de categoría: ya implícitos en el alias específico
  // que sí se marcó consumido (p. ej. "tacos" en "tacos de asada").
  "taco", "tacos", "torta", "tortas", "refresco", "refrescos",
  "otro", "otra", "otros", "otras",
]);

function normalizar(texto) {
  return texto
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

/** "dos, no, tres" / "dos no mejor tres" -> se queda con el número final dicho. */
function resolverCorrecciones(texto) {
  const numeroRegex = Object.keys(NUMBER_WORDS).join("|");
  const patron = new RegExp(`\\b(${numeroRegex}|\\d+)\\b(?:\\s*,?\\s*no,?\\s*(?:mejor\\s*)?)(\\b(${numeroRegex}|\\d+)\\b)`, "gi");
  return texto.replace(patron, "$2");
}

function numeroDesde(palabra) {
  const limpio = palabra.replace(/[^a-z0-9]/gi, "");
  if (limpio in NUMBER_WORDS) return NUMBER_WORDS[limpio];
  if (/^\d+$/.test(limpio)) return parseInt(limpio, 10);
  return null;
}

/** Busca un número justo antes de idx y marca esa palabra como consumida (para no perderla del control de confianza). */
function buscarCantidadAntes(texto, idx, marcar, ventana = 15) {
  const desde = Math.max(0, idx - ventana);
  const antes = texto.slice(desde, idx);
  const palabras = [...antes.matchAll(/[a-z0-9]+/g)].reverse();
  for (const p of palabras) {
    const n = numeroDesde(p[0]);
    if (n !== null) {
      marcar(desde + p.index, desde + p.index + p[0].length);
      return n;
    }
  }
  return 1;
}

/** Busca "sin X" cerca de desdeIdx y marca la frase completa como consumida. */
function buscarQuitarCerca(texto, desdeIdx, marcar, ventana = 30) {
  const seccion = texto.slice(desdeIdx, desdeIdx + ventana);
  const match = seccion.match(/sin ([a-z]+(?:\s+[a-z]+)?)/);
  if (!match) return [];
  marcar(desdeIdx + match.index, desdeIdx + match.index + match[0].length);
  return [match[1].trim()];
}

/** Primera capa: parser de reglas por coincidencia de alias, sin IA. */
function parseoPorReglas(transcriptOriginal, catalogo) {
  const superTorta = catalogo.find((p) => p.categoria === "super_torta");
  const productosSimples = catalogo.filter((p) => p.categoria !== "super_torta" && p.categoria !== "torta");
  const tortasSimples = catalogo.filter((p) => p.categoria === "torta");

  const texto = normalizar(resolverCorrecciones(transcriptOriginal));
  const consumido = new Array(texto.length).fill(false);
  const marcar = (i, f) => {
    for (let k = i; k < f; k++) consumido[k] = true;
  };
  const solapa = (i, f) => {
    for (let k = i; k < f; k++) if (consumido[k]) return true;
    return false;
  };

  const lineas = [];
  const no_reconocidos = [];

  // 1) Combos de torta: "torta de X[, Y[ y Z...]]" — 1 ingrediente = torta
  // normal, 2 = Super Torta, 3+ = Super Torta con selección inválida (el
  // backend la marcará como error; el parser nunca decide por su cuenta).
  // La lista de ingredientes está acotada a INGREDIENTES_TORTA a propósito:
  // así el regex nunca se traga palabras siguientes como "revuelta" o "sin".
  const ING = "(?:milanesa|jamon|pierna)";
  const tortaRegex = new RegExp(`torta de (${ING}(?:(?:,| y )\\s*${ING})*)`, "g");
  let m;
  while ((m = tortaRegex.exec(texto)) !== null) {
    const inicio = m.index;
    const fin = inicio + m[0].length;
    if (solapa(inicio, fin)) continue;

    const crudos = m[1].split(/,| y /).map((s) => s.trim()).filter(Boolean);
    const ingredientes = crudos.filter((i) => INGREDIENTES_TORTA.includes(i));
    if (ingredientes.length === 0) continue;

    marcar(inicio, fin);
    const cantidad = buscarCantidadAntes(texto, inicio, marcar);
    const quitar = buscarQuitarCerca(texto, fin, marcar);

    if (ingredientes.length === 1) {
      const producto = tortasSimples.find((p) => p.sinonimos.includes(ingredientes[0]));
      if (producto) {
        lineas.push({
          id_producto: producto.id,
          cantidad,
          selecciones: { ingredientes: [], modo: null },
          quitar,
          fragmento: m[0],
        });
      }
      continue;
    }

    const ventanaModo = texto.slice(fin, fin + 20);
    const modoMatch = ventanaModo.match(/revuelta|mitad y mitad/);
    const modo = modoMatch ? modoMatch[0] : null;
    if (modoMatch) marcar(fin + modoMatch.index, fin + modoMatch.index + modoMatch[0].length);

    lineas.push({
      id_producto: superTorta.id,
      cantidad,
      selecciones: { ingredientes, modo },
      quitar,
      fragmento: m[0],
    });
  }

  // 2) Resto de productos (tacos, refrescos) por alias directo.
  for (const producto of productosSimples) {
    for (const aliasCrudo of [producto.nombre, ...(producto.sinonimos ?? [])]) {
      const alias = normalizar(aliasCrudo);
      let desde = 0;
      while (true) {
        const idx = texto.indexOf(alias, desde);
        if (idx === -1) break;
        const fin = idx + alias.length;
        desde = fin;
        if (solapa(idx, fin)) continue;
        marcar(idx, fin);

        lineas.push({
          id_producto: producto.id,
          cantidad: buscarCantidadAntes(texto, idx, marcar),
          selecciones: { ingredientes: [], modo: null },
          quitar: buscarQuitarCerca(texto, fin, marcar),
          fragmento: aliasCrudo,
        });
      }
    }
  }

  // 3) Un puñado de productos fuera de catálogo conocidos -> no_reconocidos.
  for (const item of NO_CATALOGO_CONOCIDOS) {
    const idx = texto.indexOf(item);
    if (idx === -1 || solapa(idx, idx + item.length)) continue;
    marcar(idx, idx + item.length);
    no_reconocidos.push({ texto: item, cantidad: buscarCantidadAntes(texto, idx, marcar) });
  }

  // ¿Qué tan seguro está el parser de que cubrió todo el enunciado?
  let restante = texto;
  for (let i = 0; i < texto.length; i++) if (consumido[i]) restante = restante.substring(0, i) + " " + restante.substring(i + 1);
  const palabrasSobrantes = restante
    .replace(/[.,;¡!¿?]/g, " ")
    .split(/\s+/)
    .filter((p) => p && !PALABRAS_IGNORABLES.has(p));

  // Cero tolerancia: cualquier palabra con contenido (sobre todo un número
  // suelto, señal de una segunda cantidad que el parser no pudo enganchar a
  // ningún producto) hace que se prefiera el LLM en vez de arriesgar un pedido mal armado.
  const confiable = (lineas.length > 0 || no_reconocidos.length > 0) && palabrasSobrantes.length === 0;

  return { lineas, no_reconocidos, confiable };
}

function catalogoParaPrompt(catalogo) {
  return catalogo.map((p) => ({
    id: p.id,
    nombre: p.nombre,
    categoria: p.categoria,
    sinonimos: p.sinonimos,
    ...(p.categoria === "super_torta"
      ? { ingredientesPermitidos: p.ingredientesPermitidos, modos: p.modos }
      : {}),
  }));
}

function promptSistema(catalogo) {
  return `Eres el módulo que interpreta pedidos hablados en una tienda de tacos y tortas.

Catálogo válido (usa SOLO estos id_producto, nunca inventes otros ni devuelvas precios):
${JSON.stringify(catalogoParaPrompt(catalogo))}

Reglas:
- Cada mención de un producto es una línea independiente en "lineas", incluso si el mismo producto se repite.
- Tacos y refrescos no llevan selecciones ni modo.
- Torta de un solo ingrediente: usa el id_producto de esa torta específica.
- Si se mencionan EXACTAMENTE 2 ingredientes de torta juntos, es "Super Torta" (usa su id_producto), con selecciones.ingredientes = esos 2 ingredientes en minúsculas sin acentos (milanesa, jamon, pierna).
- Si se mencionan 3 o más ingredientes de torta juntos, NO ADIVINES: crea la línea de Super Torta con selecciones.ingredientes = TODOS los ingredientes mencionados (el backend la marcará como inválida por tener más de 2).
- selecciones.modo solo aplica a Super Torta ("mitad y mitad" o "revuelta"), y SOLO si el cliente lo dijo explícitamente; si no lo dijo, usa null.
- "quitar" es una lista de texto libre de lo que el cliente pidió quitar (ej. "cebolla"); es solo informativo.
- cantidad es siempre un entero positivo. Si el cliente se corrige ("dos, no, tres"), usa el número final.
- Cualquier producto/bebida pedido que NO esté claramente en el catálogo va en "no_reconocidos" con su texto tal cual y su cantidad. Nunca le asignes un id_producto del catálogo a algo que no coincide con claridad.
- Nunca calcules ni incluyas precios ni totales.
- Responde ÚNICAMENTE con JSON, sin texto adicional, con este formato exacto:
{"lineas":[{"id_producto":0,"cantidad":1,"selecciones":{"ingredientes":[],"modo":null},"quitar":[],"fragmento":""}],"no_reconocidos":[{"texto":"","cantidad":1}]}`;
}

async function llamarLLM(transcript, catalogo) {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("Falta GROQ_API_KEY en server/.env");

  const res = await fetch(GROQ_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "openai/gpt-oss-20b",
      temperature: 0,
      // "low": gasta menos tokens "pensando" antes de responder — más rápido,
      // más barato, y deja más margen para que sí alcance a emitir el JSON
      // final (gpt-oss a veces agota el presupuesto de tokens razonando y
      // nunca llega a producir el JSON, lo que Groq rechaza como inválido).
      reasoning_effort: "low",
      max_completion_tokens: 1024,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: promptSistema(catalogo) },
        { role: "user", content: transcript },
      ],
    }),
  });

  if (!res.ok) {
    const detalle = await res.text();
    throw new Error(`Groq LLM respondió ${res.status}: ${detalle}`);
  }

  const data = await res.json();
  const contenido = data.choices?.[0]?.message?.content;
  if (!contenido) throw new Error("Groq LLM no devolvió contenido (probablemente se quedó sin tokens razonando).");

  const parsed = JSON.parse(contenido);
  return { lineas: parsed.lineas ?? [], no_reconocidos: parsed.no_reconocidos ?? [] };
}

/** Segunda capa: LLM barato, solo cuando el parser de reglas no está seguro. Un reintento — el fallo de JSON vacío es intermitente. */
async function interpretarConLLM(transcript, catalogo) {
  try {
    return await llamarLLM(transcript, catalogo);
  } catch (err) {
    console.warn("interpretarConLLM: primer intento falló, reintentando —", err.message);
    return llamarLLM(transcript, catalogo);
  }
}

/**
 * interpretar(texto, catalogo) -> pedido
 *
 * Primero intenta el parser de reglas (rápido, gratis, determinista). Solo
 * cuando no puede dar cuenta con seguridad de todo el enunciado, cae al LLM.
 */
export async function interpretar(transcript, catalogo) {
  const resultado = parseoPorReglas(transcript, catalogo);
  if (resultado.confiable) {
    return { lineas: resultado.lineas, no_reconocidos: resultado.no_reconocidos };
  }
  try {
    return await interpretarConLLM(transcript, catalogo);
  } catch (err) {
    // El LLM falló incluso tras reintentar: mejor mostrar en pantalla lo que
    // el parser de reglas sí logró (aunque sea parcial) que tumbar el
    // pedido completo — el mesero siempre puede corregir a mano.
    console.error("interpretar: LLM no disponible, usando resultado parcial del parser de reglas —", err.message);
    return { lineas: resultado.lineas, no_reconocidos: resultado.no_reconocidos };
  }
}
