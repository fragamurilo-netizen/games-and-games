#!/usr/bin/env bash
# APK de teste (debug, arm64) sem Android SDK nem Gradle: usa o modelo pronto do Godot e assina
# com o uber-apk-signer (chave de debug). Sem o plugin de compras: a build de debug não cobra.
# Requisitos: godot 4.7.2 no PATH, modelos de exportação instalados, Java 17+ e o
#   uber-apk-signer.jar (https://github.com/patrickfav/uber-apk-signer) em $SIGNER.
# Uso: tools/build_debug_apk.sh [saida.apk]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build/MaisUmaRodada-debug.apk}"
SIGNER="${SIGNER:-/opt/apk/signer.jar}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# O Godot só confere se o SDK tem adb e apksigner; um SDK mínimo basta para exportar sem assinar.
SDK="$WORK/sdk"
mkdir -p "$SDK/platform-tools" "$SDK/build-tools/36.0.0"
printf '#!/bin/sh\necho "Android Debug Bridge version 1.0.41"\n' > "$SDK/platform-tools/adb"
printf '#!/bin/sh\nexit 0\n' > "$SDK/build-tools/36.0.0/apksigner"
chmod +x "$SDK/platform-tools/adb" "$SDK/build-tools/36.0.0/apksigner"
SETTINGS="$(ls "$HOME"/.config/godot/editor_settings-4*.tres 2>/dev/null | head -1 || true)"
if [ -n "$SETTINGS" ]; then
	sed -i "s#^export/android/android_sdk_path = .*#export/android/android_sdk_path = \"$SDK\"#" "$SETTINGS"
fi
# Cópia do projeto sem o plugin de compras e com exportação direta (sem Gradle, sem assinatura).
mkdir -p "$WORK/proj"
(cd "$ROOT" && tar --exclude=./build -cf - .) | tar -xf - -C "$WORK/proj"
sed -i 's#^enabled=PackedStringArray("res://addons/GodotGooglePlayBilling/plugin.cfg")#enabled=PackedStringArray()#' "$WORK/proj/project.godot"
sed -i 's/^gradle_build\/use_gradle_build=true/gradle_build\/use_gradle_build=false/; s/^package\/signed=true/package\/signed=false/; s/^gradle_build\/export_format=1/gradle_build\/export_format=0/' "$WORK/proj/export_presets.cfg"
godot --headless --path "$WORK/proj" --import >/dev/null 2>&1 || true
godot --headless --path "$WORK/proj" --export-debug "Android" "$WORK/unsigned.apk"
java -jar "$SIGNER" -a "$WORK/unsigned.apk" -o "$WORK/signed" --allowResign
mkdir -p "$(dirname "$OUT")"
cp "$WORK"/signed/*-aligned-debugSigned.apk "$OUT"
echo "APK: $OUT"
