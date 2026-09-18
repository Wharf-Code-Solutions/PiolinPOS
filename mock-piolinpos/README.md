# PiolinPOS — Prototipo funcional

POS para una tienda de abarrotes con área de preparación, con dos módulos separados: **Pedidos** (POS / ventanilla) y **Comandas** (cocina). Sin backend — todo corre en el navegador y persiste en `localStorage`, sincronizado en tiempo real entre pestañas.

## Ejecutar localmente

```bash
npm install
npm run dev
```

Abre `http://localhost:5173/#/pedidos` y, en otra pestaña, `http://localhost:5173/#/comandas` para ver la sincronización en vivo (crea un pedido en una y aparece de inmediato en la otra).

## Build de producción

```bash
npm run build
npm run preview
```

## Desplegar en Vercel

Proyecto Vite estándar, sin variables de entorno ni backend. Basta con importar el repo en Vercel (framework: Vite) o ejecutar `vercel` desde esta carpeta.

## Estructura

```
src/
├── components/
│   ├── pos/       — catálogo, carrito, notas, pedido por voz, confirmación
│   ├── kitchen/   — tarjetas de comanda, finalizados, vista de ticket
│   ├── orders/    — pedidos recientes (compartido)
│   └── common/    — nav, toasts, hoja modal
├── pages/         — OrdersPage (Pedidos), ComandasPage (Comandas)
├── store/         — orderStore.ts (Zustand + persist + sync entre pestañas)
├── data/          — catálogo y pedidos de demostración
├── types/         — modelo de datos
└── utils/         — storage, parser de pedido por voz
```

## Notas del prototipo

- El "pedido por voz" es una simulación de UX (frases predefinidas → interpretación → carrito), no reconocimiento de voz real.
- La vista previa de comanda térmica es representativa; no controla una impresora física.
- "Restablecer demo" (parte inferior de la barra de navegación) regresa el estado a los pedidos de demostración iniciales — útil para repetir la presentación.
