# PiolinPOS — Arquitectura v1 (entrega)

Fecha: 2026-11-17 · Base: `docs/requerimientos/entrevista-cliente-2026-10-09.md`, `docs/arquitectura/schema.sql`

> Esta versión sustituye a la arquitectura con Supabase del 2026-10-16 (descartada el 2026-10-21).

## 1. Decisiones vigentes

| # | Decisión | Motivo |
|---|---|---|
| D1 | App móvil **Flutter**, solo Android | R12: todo opera desde el celular. |
| D2 | **SQLite local** (`sqflite`) como única base de datos | Funciona sin internet ni luz (R13); sin costo de servidor. |
| D3 | **1 celular** en el alcance de entrega | Sin servidor no hay datos compartidos entre celulares. |
| D4 | **Respaldo en Google Drive** (permiso `drive.file`): semanal automático, tras cada corte y manual | Único "backend": protege contra pérdida o robo del celular. |
| D5 | Sin usuarios ni PIN | R16 descartado. |
| D6 | Turno del negocio: un turno abierto a la vez, corte con efectivo esperado vs contado | Una caja física. |
| D7 | Inventario: empaquetados se descuentan al cobrar; carnes/pan por compra y conteo físico | Simplifica recetas. |
| D8 | **Impresora en espera**: cada ronda se guarda con `print_status = PENDING` | Se conecta al definir el modelo (R17) sin cambiar datos. |
| D9 | **Pedido por voz en espera** | Requiere un servidor para resguardar la API key. |
| D10 | Distribución por **APK firmado** (sin Play Store) | Decisión del proyecto. |

## 2. Vista general

```
┌──────────────────────────── Celular (Flutter) ────────────────────────────┐
│ features/ (pantallas)                                                     │
│     │  StoreScope (InheritedNotifier)                                      │
│     ▼                                                                      │
│ PosStore (ChangeNotifier)  ── domain/ (precios, promociones, corte)        │
│     │  estado en memoria: catálogo, inventario, turno y cuentas abiertas   │
│     ▼                                                                      │
│ PosRepository ── sqflite ── piolinpos.db (esquema v1 + migraciones)        │
│                                                                            │
│ services/backup_service ── Google Sign-In + Drive API (copia del .db)      │
│ services/report_export  ── PDF / CSV + compartir                           │
│ widgets/barcode_scanner ── mobile_scanner (cámara)                         │
└────────────────────────────────────────────────────────────────────────────┘
```

Regla: las pantallas solo hablan con `PosStore`. El store escribe primero en SQLite y después
actualiza la memoria y notifica; si la base rechaza la operación, la UI muestra el error.

## 3. Estructura de `app/lib`

```
lib/
├─ main.dart           arranque: registro de errores + apertura de la base
├─ app/                router (go_router), tema (design/DESIGN.md), app
├─ core/               dinero en centavos, fechas, UUID v7, registro de errores
├─ data/
│  ├─ models.dart      entidades
│  ├─ pos_store.dart   controlador (+ store/*.dart por área: pedidos, catálogo,
│  │                   inventario, turno, reportes)
│  └─ db/              esquema, migraciones, datos base y repositorio SQLite
├─ domain/             reglas puras y probadas: pricing.dart, shift_cash.dart
├─ services/           respaldo en Drive, exportación de reportes
├─ widgets/            componentes del sistema de diseño, diálogos, escáner
└─ features/           cuentas, pedido, cobro, turno, catalogo, inventario,
                       reportes, ajustes
```

## 4. Datos

- Esquema completo en `docs/arquitectura/schema.sql` (generado de `app/lib/data/db/schema.dart`).
- Dinero en centavos, cantidades en milésimas, porcentajes en puntos base, IDs UUID v7.
- **Libro mayor de inventario** (`inventory_movements`) de solo inserción; un trigger mantiene
  `current_stock_milli`.
- Los pedidos guardan **snapshot** de nombre, precio y modificadores (R14).
- Restricciones en la base: un solo turno abierto, descuento con motivo, cancelación con motivo,
  no agregar productos a cuentas cerradas.
- **Migraciones**: subir `schemaVersion` y agregar las sentencias en `migrations` (schema.dart).
  Nunca editar una versión publicada: los celulares la aplican al actualizar el APK.

## 5. Reglas de negocio

| Regla | Dónde |
|---|---|
| Totales, promociones (%, combo, NxM con vigencia), descuento redondeado al peso | `domain/pricing.dart` |
| Corte: fondo + ventas efectivo − gastos de caja ± entradas/retiros | `domain/shift_cash.dart` |
| Folio diario `A-001` por día operativo del turno | `PosRepository.nextFolio` |
| Cierre mensual inmutable, día 4 del mes siguiente (margen para gastos tardíos) | `store_reports.dart` |
| Producto ligado a insumo agotado → se marca "Agotado" | `store_orders.dart` |

## 6. Respaldo

1. La dueña conecta la cuenta de Google del negocio en **Ajustes › Respaldo**.
2. Se sube una copia consistente de `piolinpos.db` a la carpeta *PiolinPOS Respaldos* (se conservan 8).
3. Automático: al abrir/volver a la app si pasaron 7 días y después de cada corte de caja.
4. Restaurar: descarga, valida la cabecera SQLite, guarda copia local `antes_de_restaurar.db`,
   reemplaza la base y recarga.

Configuración del cliente OAuth: `docs/configuracion-google-drive.md`.

## 7. Pendientes que afectan la arquitectura

- Impresora (R17): implementar `PrinterPort` + cola sobre `order_rounds.print_status`.
- Pedido por voz: requiere un servicio intermedio para la API key.
- Varios celulares: requeriría un servidor de sincronización.
