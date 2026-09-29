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

## Build completo (Godot + Fight Studio original)

O preset usa Gradle Build. O workflow `.github/workflows/corner-office.yml` compila `android-studio-plugin`, copia os AARs para `game/addons/corner_office_studio/bin/`, instala templates 4.4.1 e exporta o APK de debug. O artefato se chama `corner-office-android-debug`. Confirmar o resultado do workflow antes de afirmar que o APK existe.

Para build local: Gradle 8.2.1 e Android Gradle Plugin 8.2.0. Execute `gradle -p android-studio-plugin :plugin:assembleDebug :plugin:assembleRelease`, copie `plugin/build/outputs/aar/plugin-*.aar` para o diretório `bin/` do addon e instale o Android Build Template pelo menu Project → Install Android Build Template. Rode também `python tools/build_studio_bundle.py`.

A WebView roda o renderer original do laboratório, com código, fontes, catálogo e replay incorporados. Não depende de Python ou internet no aparelho. O navegador externo é apenas a alternativa de desenvolvimento no desktop.

## Exportar e instalar

```bash
godot --headless --path game --import
godot --headless --path game --export-debug "Android" build/android/corner-office-debug.apk
adb install -r game/build/android/corner-office-debug.apk
```

Para release: configure um keystore de release (nunca commitar — use variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`) e use `--export-release`. Para a Play Store, ative *Gradle Build* no preset e gere `.aab`.

SDK/target acima são os defaults verificados no [código da versão Godot 4.4.1](https://github.com/godotengine/godot/blob/4.4.1-stable/platform/android/java/app/config.gradle), não uma declaração de atendimento aos requisitos atuais da Play Store. Antes de distribuição pública, atualizar toolchain/target e testar em aparelho.
