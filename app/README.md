# PiolinPOS · app Flutter

Ver el README de la raíz del repositorio para la visión general.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run --release        # celular por USB
```

## Código

```
lib/
├─ main.dart        registro de errores + apertura de SQLite
├─ app/             router (go_router), tema, app
├─ core/            dinero (centavos), fechas, ids (UUID v7), registro de errores
├─ data/
│  ├─ models.dart
│  ├─ pos_store.dart          controlador (ChangeNotifier + StoreScope)
│  ├─ store/                  extensiones por área: pedidos, catálogo, inventario, turno, reportes
│  └─ db/                     schema.dart (esquema + migraciones), seed.dart, pos_repository.dart
├─ domain/          pricing.dart (totales y promociones), shift_cash.dart (corte)
├─ services/        backup_service.dart (Drive), report_export.dart (PDF/CSV)
├─ widgets/         sistema de diseño, diálogos, escáner
└─ features/        cuentas, pedido, cobro, turno, catalogo, inventario, reportes, ajustes
```

## Rutas

| Ruta | Pantalla |
|---|---|
| `/cuentas` · `/menu` · `/inventario` · `/reportes` | Pestañas (barra inferior) |
| `/menu/confirmar` | Confirmar pedido / ronda |
| `/cuenta/:id` | Detalle de cuenta (rondas, quitar, juntar, cancelar) |
| `/cobrar/:id` | Cobro |
| `/turno` | Apertura, movimientos de caja y corte |
| `/catalogo` (+ `/producto[/:id]`, `/categorias`, `/modificadores`, `/promociones`) | Menú y precios |
| `/insumo[/:id]`, `/proveedores`, `/conteo`, `/gastos` | Inventario y gastos |
| `/ajustes` (+ `/respaldo`, `/categorias-gasto`, `/acerca`) | Ajustes |

## Cambiar el esquema de la base

1. Sube `schemaVersion` en `lib/data/db/schema.dart`.
2. Agrega las sentencias en `migrations[nuevaVersión]`.
3. Regenera `docs/arquitectura/schema.sql` si cambian tablas.
4. Nunca edites `schemaV1`: los celulares en uso ya lo tienen aplicado.
