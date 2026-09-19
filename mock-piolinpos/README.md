# PiolinPOS — Prototipo funcional con pedidos por voz

POS para una tienda de tacos y tortas, con dos módulos separados: **Pedidos** (POS / ventanilla) y **Comandas** (cocina). El pedido se puede armar tocando el catálogo o dictándolo por voz — la voz se transcribe y se interpreta de verdad (Whisper + un modelo de lenguaje vía [Groq](https://console.groq.com)), pero siempre se muestra en pantalla para revisar y corregir antes de confirmar. Sin base de datos ni impresora: los pedidos persisten en `localStorage` del navegador, sincronizados en tiempo real entre pestañas/dispositivos.

## Requisitos

- **Node.js 18 o superior** (recomendado 20+ LTS). Verifica con `node --version`. Si acabas de instalarlo, **abre una terminal nueva** para que tome el PATH actualizado.
- **OpenSSL** en la terminal (ya viene con Git for Windows, macOS y la mayoría de distros Linux) — se usa para generar el certificado HTTPS local.
- Una **API key de Groq** (tiene capa gratuita) — créala en [console.groq.com](https://console.groq.com) → API Keys.

## 1. Instalar dependencias

Frontend (raíz del proyecto):

```bash
npm ci
```

Backend:

```bash
cd server
npm install
cd ..
```

## 2. Configurar la API key de Groq

Copia la plantilla y edítala:

```bash
cp server/.env.example server/.env
```

`server/.env`:

```
GROQ_API_KEY=gsk_tu_key_aqui
PORT=4000
```

`server/.env` está en `.gitignore` — la key nunca se sube al repositorio ni se expone en el frontend.

## 3. Generar el certificado HTTPS local

El micrófono (`getUserMedia`) solo funciona en `localhost` o por HTTPS — ni Chrome ni Safari lo permiten por `http://` en otra IP. Genera un certificado autofirmado (una sola vez):

```bash
npm run cert
```

Esto crea `certs/dev-cert.pem` y `certs/dev-key.pem` (tampoco se suben al repo), detectando automáticamente tu IP de red local. **Vuelve a correr `npm run cert` si cambias de red Wi-Fi** (tu IP de LAN cambia y el certificado viejo deja de cubrirla).

## 4. Correr el sistema

Necesitas **dos terminales abiertas al mismo tiempo**.

**Terminal 1 — backend:**

```bash
cd server
npm run dev
```

Debe imprimir: `Servidor de voz de PiolinPOS escuchando en http://localhost:4000`

**Terminal 2 — frontend:**

```bash
npm run dev
```

Debe imprimir algo como:

```
➜  Local:   https://localhost:5173/
➜  Network: https://192.168.x.x:5173/
```

## 5. Probar desde tu computadora

1. Abre `https://localhost:5173/#/pedidos` en tu navegador (Chrome/Edge/Firefox — no dentro de un panel embebido).
2. Verás una advertencia de "conexión no privada": es el certificado autofirmado del paso 3, es normal en desarrollo local. Clic en **Avanzado** → **Continuar a localhost (no seguro)**.
3. Abre `https://localhost:5173/#/comandas` en otra pestaña. Crea un pedido en Pedidos y confirma que aparece de inmediato en Comandas (sincronización en vivo).
4. Toca **"Tomar pedido por voz"**, mantén presionado el micrófono, di un pedido (ej. "dos tacos de pastor y una coca"), suelta. En unos segundos debe transcribir y armar las líneas del pedido para revisar antes de agregarlo.

## 6. Probar desde un celular

1. Conecta el celular a la **misma red Wi-Fi** que la computadora.
2. Copia la URL que la Terminal 2 imprimió junto a `Network:` (ej. `https://192.168.100.84:5173`) y ábrela en el navegador del celular en `/#/pedidos`.
3. Acepta la advertencia de seguridad igual que en la computadora: en Chrome Android, **Avanzado → Continuar**; en Safari/iOS, **Mostrar detalles → Visitar este sitio web**.
4. Si Windows muestra un aviso del Firewall pidiendo permitir el acceso a Node.js, dale **Permitir acceso** — si no, el celular no podrá conectarse al servidor.
5. Concede el permiso de micrófono cuando el navegador lo pida.
6. Prueba tomar un pedido por voz de principio a fin, con una sola mano sosteniendo el celular.

## Solución de problemas

- **"node" / "npm" no se reconoce como un comando** después de instalar Node.js: cierra y abre una terminal nueva (el PATH del sistema no se actualiza en terminales ya abiertas).
- **El celular no carga la página:** confirma que esté en la misma red Wi-Fi que la computadora, revisa el Firewall de Windows, y que la IP en la URL sea la actual (cambia si te reconectas a otra red).
- **El certificado dejó de servir / cambiaste de red:** vuelve a correr `npm run cert` y recarga.
- **Error de Groq al procesar la voz:** revisa que `server/.env` tenga la key correcta y que tengas cupo disponible en [console.groq.com](https://console.groq.com) (sección Billing/Usage).
- **El backend no arranca por "address already in use":** ya hay otro proceso escuchando en el puerto 4000 — ciérralo o cambia `PORT` en `server/.env`.

## Build de producción (frontend)

```bash
npm run build
npm run preview
```

El backend (`server/`) se corre por separado (`npm start` dentro de `server/`) — necesita su propio despliegue con la variable `GROQ_API_KEY` configurada donde sea que se hospede.

## Estructura

```
src/
├── components/
│   ├── pos/       — catálogo, carrito, Super Torta, pedido por voz, confirmación
│   ├── kitchen/   — tarjetas de comanda, finalizados, vista de ticket
│   ├── orders/    — pedidos recientes (compartido)
│   └── common/    — nav, toasts, hoja modal
├── pages/         — OrdersPage (Pedidos), ComandasPage (Comandas)
├── store/         — orderStore.ts (Zustand + persist + sync entre pestañas)
├── data/          — catalogo.json (fuente única de productos) + pedidos de demostración
├── hooks/         — useVoiceRecorder.ts (captura de audio real con MediaRecorder)
├── types/         — modelo de datos
└── utils/         — storage

server/            — backend de voz (Express)
├── index.js       — POST /voz
├── transcribir.js — transcripción de audio (Whisper vía Groq)
├── interpretar.js — parser de reglas + respaldo con LLM (Groq) cuando no hay certeza
├── validar.js     — única fuente de precios/total y validación de reglas de negocio
└── catalogo.js    — lee src/data/catalogo.json

scripts/
└── generate-cert.mjs — genera el certificado HTTPS local (npm run cert)
```

## Notas del prototipo

- El pedido por voz es reconocimiento real: se graba audio con `MediaRecorder`, se transcribe con Whisper y se interpreta con un parser de reglas (rápido y gratis) que solo cae a un modelo de lenguaje barato cuando no está seguro del resultado — todo vía Groq. El pedido, la transcripción y cualquier línea dudosa o no reconocida siempre se muestran en pantalla antes de agregarse al carrito.
- La vista previa de comanda térmica es representativa; no controla una impresora física.
- Sin base de datos: los pedidos persisten en `localStorage` del navegador.
- "Restablecer demo" (parte inferior de la barra de navegación) regresa el estado a los pedidos de demostración iniciales — útil para repetir la presentación.
