# PiolinPOS — Plan de trabajo para entrega al cliente

Actualizado: 2026-11-17 · Base: `docs/requerimientos/`, `docs/arquitectura/`.

## Decisiones (2026-11-17)

| # | Decisión | Resultado |
|---|---|---|
| P1 | Modelo de impresora | **En espera**. Las rondas se guardan con impresión pendiente. |
| P2 | Pedido por voz | **En espera**. |
| P3 | "Backend propio" | = **respaldo en Google Drive**. |
| P4 | Celulares | **Uno**. |
| P5 | Catálogo real | Se carga **después**, con el cliente. |

Leyenda: ✔ implementado · ⏸ en espera · ☐ pendiente.

## F0 · Base técnica
| # | Tarea | Estado |
|---|---|---|
| F0.1 | Dependencias: sqflite, uuid, Drive, pdf/csv, escáner | ✔ |
| F0.2 | Arquitectura y esquema actualizados a solo SQLite | ✔ |
| F0.3 | Esquema SQLite con triggers e índices | ✔ |
| F0.4 | Store respaldado por SQLite (reemplaza datos en memoria) | ✔ |
| F0.5 | Migraciones versionadas (`schemaVersion` + `migrations`) | ✔ |
| F0.6 | Fuentes sin internet | ☐ `google_fonts` las guarda tras el primer arranque con internet; empaquetarlas si se requiere arranque 100 % offline |

## F1 · Pedidos
| # | Tarea | Req. | Estado |
|---|---|---|---|
| F1.1 | Agregar productos a cuenta abierta (rondas) | R1 | ✔ |
| F1.2 | Juntar dos cuentas | R1 | ✔ |
| F1.3 | Cancelar cuenta y quitar producto con motivo (audit_log) | — | ✔ |
| F1.4 | Descuento % con motivo obligatorio | R3 | ✔ |
| F1.5 | Pago mixto y referencia de transferencia | R5 | ✔ |
| F1.6 | Canal LOCAL / WhatsApp | R6 | ✔ |
| F1.7 | Folio diario por día operativo | — | ✔ |
| F1.8 | Turno: fondo, entradas/retiros, corte con diferencia | — | ✔ |

## F2 · Catálogo
| # | Tarea | Req. | Estado |
|---|---|---|---|
| F2.1 | Editar y dar de baja productos | R14 | ✔ |
| F2.2 | Categorías (menú e inventario) | R14 | ✔ |
| F2.3 | Modificadores (grupos mín./máx., sobreprecio) | — | ✔ |
| F2.4 | Historial de precios | R14 | ✔ |

## F3 · Impresión — ⏸ en espera (P1)

## F4 · Respaldo
| # | Tarea | Estado |
|---|---|---|
| F4.1 | Copia consistente del `.db` | ✔ |
| F4.2 | Respaldo en Drive: semanal al abrir la app y tras cada corte | ✔ |
| F4.3 | Respaldo manual y restauración | ✔ |
| F4.4 | Indicador de respaldo en la barra; se quitó "simular sin conexión" | ✔ |
| F4.5 | Registrar cliente OAuth en Google Cloud (`docs/configuracion-google-drive.md`) | ☐ |

## F5 · Inventario y gastos
| # | Tarea | Req. | Estado |
|---|---|---|---|
| F5.1 | Alta/edición de insumos | R10 | ✔ |
| F5.2 | Proveedores | R10 | ✔ |
| F5.3 | Compras → movimiento PURCHASE | R15 | ✔ |
| F5.4 | Descuento automático por venta (producto ligado a insumo) | D7 | ✔ |
| F5.5 | Conteo físico con tolerancia | R18 | ✔ |
| F5.6 | Categorías de gasto y % de merma | R18 | ✔ |
| F5.7 | Escáner de código de barras | R2 | ✔ |

## F6 · Reportes y promociones
| # | Tarea | Req. | Estado |
|---|---|---|---|
| F6.1 | Reportes desde SQLite: ventas, top, stock bajo, ventas vs gastos | R8, R15 | ✔ |
| F6.2 | Cierre mensual + PDF/CSV compartible | R11 | ✔ |
| F6.3 | Promociones (%, combo, NxM, vigencia) | R4 | ✔ |
| F6.4 | Pedido por voz | D11 | ⏸ |

## F7 · Release
| # | Tarea | Estado |
|---|---|---|
| F7.1 | Ícono y logo | ✔ (diseño provisional propio; ver nota) |
| F7.2 | `applicationId`, nombre visible, versión 1.0.0+1 | ✔ |
| F7.3 | Firma de release (`scripts/generar_keystore.sh`) | ☐ generar y respaldar la llave |
| F7.4 | Build ofuscado (`scripts/build_release.sh`) | ✔ |
| F7.5 | Pantalla "Acerca de" | ✔ |
| F7.6 | Registro de errores exportable | ✔ |

> Nota F7.1: la mascota del manual de marca es un personaje con derechos de autor de terceros;
> no se usó en la app. El ícono es un sello "P" con los colores de la marca.

## F8 · Calidad y entrega
| # | Tarea | Estado |
|---|---|---|
| F8.1 | Pruebas de dominio (precios, promociones, vigencia, dinero) | ✔ `test/pricing_test.dart`, `test/widget_test.dart` |
| F8.2 | Pruebas de integración sobre SQLite | ✔ `test/store_test.dart` |
| F8.3 | Pruebas en el celular del cliente (sin internet, reinicio, corte) | ☐ |
| F8.4 | Piloto de 1 semana en el local | ☐ |
| F8.5 | Carga del catálogo real | ☐ (P5) |
| F8.6 | Manual de usuario | ✔ `docs/manual-usuario.md` |
| F8.7 | Acta de entrega (APK, versión, cuenta Drive, ubicación de la llave) | ☐ |

## Siguiente orden de trabajo

1. `flutter analyze` / `flutter test` en verde.
2. Generar llave de release y registrar OAuth de Drive.
3. Prueba en celular: flujo completo + respaldo/restauración.
4. Carga del catálogo real con el cliente.
5. Piloto y acta de entrega.
