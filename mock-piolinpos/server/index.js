import "dotenv/config";
import express from "express";
import cors from "cors";
import multer from "multer";
import { CATALOGO } from "./catalogo.js";
import { transcribir } from "./transcribir.js";
import { interpretar } from "./interpretar.js";
import { validarPedido } from "./validar.js";

const app = express();
app.use(cors());

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 15 * 1024 * 1024 } });

app.post("/voz", upload.single("audio"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "Falta el archivo de audio (campo 'audio')." });
    }
    const mimeType = req.file.mimetype || "audio/webm";

    const transcripcion = await transcribir(req.file.buffer, mimeType, CATALOGO);
    const pedidoCrudo = await interpretar(transcripcion, CATALOGO);
    const { lineas, no_reconocidos, total } = validarPedido(pedidoCrudo, CATALOGO);

    res.json({ transcripcion, lineas, no_reconocidos, total });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err instanceof Error ? err.message : "Error procesando la orden de voz." });
  }
});

app.get("/salud", (_req, res) => res.json({ ok: true, productos: CATALOGO.length }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Servidor de voz de PiolinPOS escuchando en http://localhost:${PORT}`);
});
