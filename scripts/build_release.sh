#!/usr/bin/env bash
# Compila el APK de release firmado y lo copia a dist/.
# Uso (desde la raíz del repo): bash scripts/build_release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

if [[ ! -f android/key.properties ]]; then
  echo "⚠  Falta app/android/key.properties: el APK se firmará con la llave de DEBUG."
  echo "   Genera la llave con: bash scripts/generar_keystore.sh"
  read -r -p "¿Continuar de todos modos? [s/N] " ok
  [[ "$ok" == "s" || "$ok" == "S" ]] || exit 1
fi

VERSION="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"

flutter pub get
flutter analyze
flutter test
flutter build apk --release --obfuscate --split-debug-info=build/symbols

mkdir -p "$ROOT/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/dist/elpiolin-pos-${VERSION}.apk"
echo "✔ APK listo: dist/elpiolin-pos-${VERSION}.apk"
echo "  Guarda también app/build/symbols/ para depurar fallos de esta versión."
