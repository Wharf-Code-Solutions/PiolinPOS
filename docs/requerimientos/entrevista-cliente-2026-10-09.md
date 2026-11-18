# Entrevista con cliente — Piolín (10/09/26)

Transcripción de notas manuscritas + interpretación técnica.

| # | Nota original | Interpretación / requerimiento |
|---|---|---|
| R1 | Que se sumen 2 cuentas de la misma persona en un corto lapso de tiempo | Agregar productos a una cuenta abierta (o fusionar dos). A cocina solo se imprime lo nuevo. |
| R2 | Inventario de bebidas (etc.) contabilizable con código de barras | Escaneo con cámara del celular para altas, conteos y ventas de productos empaquetados. |
| R3 | Descuentos sobre la nota por porcentaje. Clientes especiales al momento | Descuento % a nivel pedido, con motivo; aplicado manualmente al cobrar. |
| R4 | Uso de las promos | Motor de promociones (combos, % por producto, NxM, vigencia por fecha/día). |
| R5 | Método de pago efectivo o transferencia | `payment_method` CASH / TRANSFER; cálculo de cambio en efectivo. |
| R6 | Pedido en negocio o sobre WhatsApp | Campo `channel`: LOCAL / WHATSAPP (solo etiqueta, captura manual). |
| R7 | Impresión de tickets con rollos genéricos de Veracruz | Impresora térmica 58 mm (rollo 57 mm, el más común). |
| R8 | Reporte de ventas en dinero, productos más vendidos, o aquella que no se tiene suficiente (en celular) | Reportes en el celular: ventas $, top productos y **stock bajo**. |
| R9 | Proceso (de momento): Ray recibe pedido → pasa a cocina (aquí queda el ticket) → se da al cliente el pedido (sin ticket) | Solo se imprime comanda para cocina; el cliente no recibe ticket. |
| R10 | Productos de inventario: carnes, refrescos, diferentes proveedores | Catálogo de proveedores; insumos en kg (carnes) y piezas (refrescos). |
| R11 | Duración de reportes: mensuales, tenerlos cada mes para irlos guardando, margen de tiempo extra | Cierre mensual con reporte exportable (PDF/CSV) y retención histórica. |
| R12 | Sin equipos de cómputo, solo internet | Todo opera desde celular; hay internet disponible para respaldo/sincronización. |
| R13 | Si se va la luz, que los pedidos se guarden en la app aunque no salga el ticket | Respaldo offline; impresión desacoplada con cola de reimpresión. **Impresora con batería (obligatorio).** |
| R14 | Poder actualizar los precios del menú por sí misma cada cierto tiempo | CRUD de catálogo/precios en la app; los pedidos guardan el precio del momento. |
| R15 | Comparativa dinero gastado en insumos vs dinero ganado en ventas; la compra es muy variada, ella haría el manejo en la app | Registro de compras/gastos por categoría y proveedor; reporte ventas vs gastos (utilidad). |
| R16 | Opcional: usuarios para los 2 que la manejan, registrar quién atiende | **Descartado**: no habrá usuarios, operadores ni PIN. |
| R17 | Revisar impresoras para comprarla nosotros y que nos pasen el dinero; una impresora para la posteridad | Seleccionar modelo durable, ESC/POS, Bluetooth, 58 mm, con batería. |
| R18 | Manejar cosas fuera del inventario con un % de margen de error y opción para agregar gasto imprevisto | Insumos no inventariados como gasto con % de merma configurable; gasto imprevisto rápido. |

## Resueltos (2026-10-16)
- Celulares: **2 celulares, uso alterno (no simultáneo)**. Sin tiempo real; datos compartidos vía Supabase.
- Turno: **del negocio**, 1 por día, con relevo entre celulares (una caja física compartida).
- R8: "no se tiene suficiente" = **stock bajo**.
- R13: impresora **con batería**.
- R16: **sin usuarios ni PIN**; todas las funciones abiertas en ambos celulares.
- R6: WhatsApp **solo como etiqueta de canal**.
- Inventario: empaquetados (código de barras) **se descuentan por venta**; carnes y pan **solo por compra y conteo físico**.
- Facturación CFDI: **no**.
- Pedido por voz: **sí, en v1**.

## Actualizaciones posteriores
- 2026-10-21: se descarta Supabase; la app usa **solo SQLite** con respaldo en Google Drive.
- 2026-11-17: alcance de entrega **1 celular**; impresora y pedido por voz **en espera**.

## Pendientes
- Modelo exacto de impresora (R17).
