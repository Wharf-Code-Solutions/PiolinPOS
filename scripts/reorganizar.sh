#!/usr/bin/env bash
# Reorganización única de la carpeta POSPiolin a la estructura del repositorio:
#
#   POSPiolin/
#   ├─ app/       (antes PiolinPOS/)
#   ├─ docs/      (arquitectura, requerimientos, planeación, entregables)
#   ├─ design/    (DESIGN.md, mocks de Stitch, manual de marca)
#   └─ scripts/
#
# Uso (desde POSPiolin/): bash scripts/reorganizar.sh
# Es seguro correrlo dos veces: omite lo que ya está en su lugar.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

move() { # move <origen> <destino>
  if [[ -e "$1" && ! -e "$2" ]]; then
    mkdir -p "$(dirname "$2")"
    mv "$1" "$2"
    echo "  movido: $1 → $2"
  fi
}

remove() {
  if [[ -e "$1" ]]; then
    rm -rf "$1"
    echo "  eliminado: $1"
  fi
}

echo "1) Proyecto Flutter → app/"
move "PiolinPOS" "app"

echo "2) Diseño → design/"
move "stitch_el_piol_n_pos_app/el_piol_n_pos/DESIGN.md" "design/DESIGN.md"
remove "stitch_el_piol_n_pos_app/el_piol_n_pos"
move "stitch_el_piol_n_pos_app" "design/stitch"
move "Manual de Marca El Piolín.html" "design/manual-de-marca.html"
move "Mock El Piolín POS.html" "design/mock-pos.html"

echo "3) Entregables → docs/entregables/"
move "Proyecto_PiolinPOS.docx" "docs/entregables/Proyecto_PiolinPOS.docx"

echo "4) Archivos obsoletos del código"
remove "app/lib/data/mock_data.dart"
remove "app/lib/data/catalog_defaults.dart"
remove "app/lib/features/catalogo/nuevo_producto_screen.dart"
remove "app/piolinpos.iml"
remove "app/android/piolinpos_android.iml"

echo "5) Artefactos de compilación (se regeneran)"
remove "app/build"
remove "app/.dart_tool"
remove "app/android/.gradle"
remove "app/android/.kotlin"

chmod +x scripts/*.sh 2>/dev/null || true

echo
echo "✔ Listo. Siguientes pasos:"
echo "   cd app && flutter pub get && flutter analyze && flutter test"
