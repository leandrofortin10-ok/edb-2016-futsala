#!/bin/bash
# Mueve los assets del build web a una carpeta versionada (v/<versión>/assets)
# y configura el engine de Flutter para buscarlos ahí (config.assetBase).
#
# Por qué: Flutter genera archivos con el mismo nombre en cada build (por
# ejemplo la fuente de íconos recortada, assets/fonts/MaterialIcons-Regular.otf)
# y el navegador los guarda en caché. Con una carpeta por versión, cada deploy
# usa URLs nuevas y se pueden cachear como immutable sin servir versiones viejas.
#
# Uso: scripts/version_assets.sh <dir_build_web> <versión>
set -euo pipefail

BUILD_DIR="${1:?falta el directorio del build (ej. build/web)}"
VERSION="${2:?falta la versión (ej. el hash corto del commit)}"

if [ ! -d "$BUILD_DIR/assets" ]; then
  echo "No existe $BUILD_DIR/assets" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR/v/$VERSION"
mv "$BUILD_DIR/assets" "$BUILD_DIR/v/$VERSION/assets"

# _flutter.loader.load({ ... }) → _flutter.loader.load({ config: { assetBase: ... }, ... })
BOOTSTRAP="$BUILD_DIR/flutter_bootstrap.js"
grep -q '_flutter.loader.load({' "$BOOTSTRAP" || { echo "No se encontró _flutter.loader.load en $BOOTSTRAP" >&2; exit 1; }
sed -i "s|_flutter.loader.load({|_flutter.loader.load({ config: { assetBase: \"/v/$VERSION/\" },|" "$BOOTSTRAP"

echo "Assets versionados en /v/$VERSION/"
