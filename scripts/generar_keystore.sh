#!/usr/bin/env bash
# Genera la llave de firma de release y app/android/key.properties.
# Uso (desde la raíz del repo): bash scripts/generar_keystore.sh
# Ninguno de los dos archivos se versiona (ver .gitignore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEYDIR="${KEYDIR:-$HOME/llaves}"
KEYSTORE="$KEYDIR/piolinpos-release.jks"
ALIAS="piolinpos"

if [[ -f "$KEYSTORE" ]]; then
  echo "Ya existe $KEYSTORE; no se sobrescribe."
  exit 1
fi

mkdir -p "$KEYDIR"
read -r -s -p "Contraseña para la llave (mín. 6 caracteres): " PASS; echo
read -r -s -p "Repite la contraseña: " PASS2; echo
[[ "$PASS" == "$PASS2" ]] || { echo "Las contraseñas no coinciden"; exit 1; }

keytool -genkeypair -v \
  -keystore "$KEYSTORE" -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=El Piolin POS, O=Wharf Code, L=Veracruz, C=MX"

cat > "$ROOT/app/android/key.properties" <<EOF
storePassword=$PASS
keyPassword=$PASS
keyAlias=$ALIAS
storeFile=$KEYSTORE
EOF
chmod 600 "$ROOT/app/android/key.properties"

echo "✔ Llave: $KEYSTORE"
echo "✔ Configuración: app/android/key.properties"
echo
echo "SHA-1 para registrar en Google Cloud (docs/configuracion-google-drive.md):"
keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$PASS" | grep -E "SHA1|SHA-1"
echo
echo "⚠  Respalda $KEYSTORE y la contraseña en dos lugares seguros."
