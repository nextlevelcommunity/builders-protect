#!/bin/zsh
set -euo pipefail
setopt null_glob

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP_NAME="Builders Protect"
APP="$ROOT/dist/$APP_NAME.app"
MASTER_ICON="$ROOT/Resources/icon_1024x1024.png"
ICNS="$ROOT/Resources/AppIcon.icns"
ICONSET="$ROOT/.build/AppIcon.iconset"

# Binário universal: roda em Apple Silicon e em Macs Intel.
# O build local usa hardened runtime desde já, para o app testado ser o mesmo
# que vai para notarização (sem surpresa só na hora de assinar de verdade).
ARCHS=(--arch arm64 --arch x86_64)
if ! swift build --package-path "$ROOT" -c "$CONFIG" "${ARCHS[@]}"; then
    echo "AVISO: build universal falhou; caindo para a arquitetura nativa." >&2
    ARCHS=()
    swift build --package-path "$ROOT" -c "$CONFIG"
fi

if [[ ! -f "$MASTER_ICON" || "$ROOT/scripts/make-icon.swift" -nt "$MASTER_ICON" ]]; then
    echo "Gerando icone..."
    swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources" >/dev/null
fi

if [[ ! -f "$ICNS" || "$MASTER_ICON" -nt "$ICNS" ]]; then
    echo "Montando AppIcon.icns..."
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    sips -z 16 16 "$MASTER_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$MASTER_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$MASTER_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$MASTER_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$MASTER_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$MASTER_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$MASTER_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$MASTER_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$MASTER_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
    cp "$MASTER_ICON" "$ICONSET/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET" -o "$ICNS"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN=""
for candidate in "$ROOT/.build/apple/Products/$CONFIG/CVEBuilder" "$ROOT/.build/$CONFIG/CVEBuilder"; do
    [[ -f "$candidate" ]] && BIN="$candidate" && break
done
[[ -n "$BIN" ]] || { echo "ERRO: binário não encontrado após o build." >&2; exit 1; }
cp "$BIN" "$APP/Contents/MacOS/CVEBuilder"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
cp "$MASTER_ICON" "$APP/Contents/Resources/icon_1024x1024.png"
for bundle in "$ROOT/.build/apple/Products/$CONFIG"/*.bundle "$ROOT/.build/$CONFIG"/*.bundle; do
    [[ -d "$bundle" ]] && cp -R "$bundle" "$APP/Contents/Resources/"
done
chmod +x "$APP/Contents/MacOS/CVEBuilder"

xattr -cr "$APP" 2>/dev/null || true
ENT_ARGS=()
[[ -f "$ROOT/Resources/BuildersProtect.entitlements" ]] && ENT_ARGS=(--entitlements "$ROOT/Resources/BuildersProtect.entitlements")
codesign --force --deep --options runtime "${ENT_ARGS[@]}" --sign - "$APP" >/dev/null 2>&1 || true

echo "$APP"
