# Configurar el respaldo en Google Drive

El respaldo usa **Google Sign-In** con el permiso `drive.file`: la app solo ve los archivos que
ella misma crea. No requiere Firebase ni `google-services.json`, pero sí un **cliente OAuth de
Android** registrado con el nombre de paquete y la huella SHA-1 de la llave que firma el APK.

> Sin este paso, al tocar "Conectar cuenta de Google" aparece un error (`ApiException: 10`).

## 1. Proyecto en Google Cloud

1. Entra a <https://console.cloud.google.com/> con la cuenta de Wharf Code.
2. Crea un proyecto, por ejemplo `piolinpos`.
3. **APIs y servicios › Biblioteca** → habilita **Google Drive API**.

## 2. Pantalla de consentimiento OAuth

1. **APIs y servicios › Pantalla de consentimiento** → tipo **Externo**.
2. Nombre de la app: *El Piolín POS*; correo de soporte: el de Wharf Code.
3. Alcances: agrega `.../auth/drive.file` (no es un alcance sensible, no requiere verificación).
4. Mientras esté en modo **Prueba**, agrega como *usuario de prueba* la cuenta de Google del
   negocio. Para quitar el límite de usuarios de prueba, publica la app (estado "En producción").

## 3. Huellas SHA-1

```bash
# Llave de release (la que firma el APK del cliente; ver docs/release.md)
keytool -list -v -keystore ~/llaves/piolinpos-release.jks -alias piolinpos | grep SHA1

# Llave de debug (para probar con flutter run)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

## 4. Clientes OAuth de Android

**APIs y servicios › Credenciales › Crear credenciales › ID de cliente de OAuth**:

| Campo | Valor |
|---|---|
| Tipo | Android |
| Nombre del paquete | `com.wharfcode.piolinpos` |
| SHA-1 | la de release (crea un segundo cliente con la SHA-1 de debug para pruebas) |

No hay que copiar el ID de cliente a la app: Google lo resuelve por paquete + SHA-1.

## 5. Probar

1. Instala el APK firmado con la llave registrada.
2. En la app: **Ajustes › Respaldo en Google Drive › Conectar cuenta de Google**.
3. **Respaldar ahora** → en Drive aparece la carpeta *PiolinPOS Respaldos* con `piolinpos_AAAA-MM-DD_HHMM.db`.

## Problemas frecuentes

| Síntoma | Causa |
|---|---|
| `ApiException: 10` | SHA-1 o paquete no registrados, o el APK está firmado con otra llave. |
| `access_denied` | La cuenta no es usuario de prueba y la app sigue en modo Prueba. |
| El respaldo automático no corre | No hay cuenta conectada, o no han pasado 7 días (el corte de caja sí lo fuerza). |
