# Android

## Requisitos

- Godot 4.4.x + **export templates** 4.4.x (Editor → Manage Export Templates).
- JDK 17 (recomendado pela Godot).
- Android SDK: `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`.
- Editor Settings → Export → Android: caminho do SDK e do debug keystore (a Godot gera um automaticamente).

## Preset

`game/export_presets.cfg` já tem o preset **Android**:

- package: `com.corneroffice.game` (**trocar antes de publicar** pelo domínio do estúdio)
- arquiteturas: arm64-v8a, armeabi-v7a
- min SDK 21, target SDK 34 (padrões da Godot 4.4; para mudar é preciso ativar Gradle Build)
- orientação: sensor (portrait e landscape)
- renderer: Compatibility (GLES3)
- saída: `game/build/android/corner-office-debug.apk` (ignorado pelo git)

## Build pela linha de comando

```bash
godot --headless --path game --import
godot --headless --path game --export-debug "Android" build/android/corner-office-debug.apk
adb install -r game/build/android/corner-office-debug.apk
```

Para release: configure um keystore de release (nunca commitar — use variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`) e use `--export-release`. Para a Play Store, ative *Gradle Build* no preset e gere `.aab`.
