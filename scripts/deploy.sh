#!/bin/bash
set -e

echo "=== Building Flutter web ==="
flutter build web --release --pwa-strategy=none

echo "=== Injecting nuke service worker ==="
cp web/flutter_service_worker.js build/web/flutter_service_worker.js

echo "=== Cache-busting main.dart.js ==="
# Generate short hash from file content
HASH=$(md5sum build/web/main.dart.js | cut -c1-8)
NEWNAME="main.dart.${HASH}.js"

# Rename the file
mv build/web/main.dart.js "build/web/${NEWNAME}"

# Update reference in flutter_bootstrap.js
sed -i "s|main.dart.js|${NEWNAME}|g" build/web/flutter_bootstrap.js

echo "  Renamed to ${NEWNAME}"

echo "=== Deploying to Firebase ==="
npx firebase deploy --only hosting

echo "=== Done ==="
