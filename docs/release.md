# Generar e instalar el APK de release

## 1. Llave de firma (una sola vez)

```bash
bash scripts/generar_keystore.sh
```

Crea `~/llaves/piolinpos-release.jks` y `app/android/key.properties` (ninguno se versiona).

> **Respalda el `.jks` y las contraseñas en dos lugares** (gestor de contraseñas + Drive del líder).
> Si se pierde la llave, los celulares no aceptarán actualizaciones del APK y habrá que desinstalar
> (perdiendo los datos locales si no hay respaldo).

Después registra la SHA-1 de esta llave en Google Cloud (`docs/configuracion-google-drive.md`).

## 2. Versión

En `app/pubspec.yaml`: `version: 1.0.0+1` → `versionName` = 1.0.0, `versionCode` = 1.
**Sube el número después del `+` en cada APK que entregues**; Android rechaza instalar un
`versionCode` menor o igual al instalado.

## 3. Compilar

```bash
bash scripts/build_release.sh
```

Corre pruebas, compila con ofuscación y deja el APK en `dist/elpiolin-pos-<versión>.apk`.
Los símbolos para depurar fallos quedan en `app/build/symbols/` (guárdalos junto con el APK).

## 4. Instalar en el celular del negocio

```bash
adb install -r dist/elpiolin-pos-1.0.0+1.apk
```

O copia el APK al celular y ábrelo (permite "Instalar apps de origen desconocido").
`-r` conserva los datos al actualizar. **No desinstales** la app para actualizar: se borra la base local.

## 5. Lista de verificación antes de entregar

- [ ] `flutter analyze` sin errores y `flutter test` en verde.
- [ ] APK firmado con la llave de release (no la de debug).
- [ ] Respaldo probado: conectar cuenta, respaldar y restaurar en un celular de prueba.
- [ ] Prueba sin internet: tomar pedido, cobrar y hacer corte en modo avión.
- [ ] Reiniciar el celular con cuentas abiertas: siguen ahí al volver a abrir la app.
- [ ] Catálogo real cargado (productos, precios, insumos).
- [ ] Manual de usuario entregado (`docs/manual-usuario.md`).
