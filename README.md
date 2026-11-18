# PiolinPOS

Punto de venta móvil para **El Piolín** (taquería y tortería): pedidos por rondas, cobro con
promociones, descuentos y pago mixto, turno con corte de caja, inventario con código de barras,
gastos y compras, reportes con cierre mensual (PDF/CSV) y respaldo en Google Drive.

Desarrollado por Wharf Code · Flutter + SQLite · Android (APK).

## Estructura

```
.
├─ app/        Proyecto Flutter (código, pruebas, Android)
├─ docs/
│  ├─ arquitectura/        arquitectura.md, schema.sql
│  ├─ requerimientos/      entrevista con el cliente (R1–R18)
│  ├─ planeacion/          plan de trabajo de entrega
│  ├─ entregables/         documento del proyecto (Gestión de Proyectos de Software)
│  ├─ manual-usuario.md
│  ├─ configuracion-google-drive.md
│  └─ release.md
├─ design/     DESIGN.md (sistema de diseño), mocks de Stitch, manual de marca
└─ scripts/    build_release.sh, generar_keystore.sh, reorganizar.sh
```

## Requisitos

- Flutter estable 3.35 o superior (Dart 3.7+), Android SDK con `cmdline-tools`.
- Celular Android con depuración USB (el emulador no es necesario).

## Desarrollo

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run            # con el celular conectado por USB
```

Las pruebas de `test/store_test.dart` usan SQLite en memoria (`sqflite_common_ffi`) y
necesitan `libsqlite3` en la máquina (`sudo apt install libsqlite3-dev`).

## Release

Ver `docs/release.md`. Resumen:

```bash
bash scripts/generar_keystore.sh   # una sola vez; respalda la llave
bash scripts/build_release.sh      # → dist/elpiolin-pos-<versión>.apk
```

El respaldo en Drive requiere registrar el cliente OAuth (`docs/configuracion-google-drive.md`).

## Estado

| Área | Estado |
|---|---|
| Pedidos, rondas, juntar/cancelar, cobro, promociones, turno | ✔ |
| Catálogo, modificadores, inventario, compras, conteo, escáner | ✔ |
| Reportes, cierre mensual PDF/CSV, respaldo Drive | ✔ |
| Impresora Bluetooth ESC/POS | En espera (comandas quedan con impresión pendiente) |
| Pedido por voz | En espera |
| Carga del catálogo real | Pendiente con el cliente |

