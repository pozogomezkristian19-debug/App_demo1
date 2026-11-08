#!/bin/bash
set -e

# Instala Flutter (estable), Dart (incluido con Flutter) y Android SDK
# en un GitHub Codespace, y los deja en el PATH de forma permanente.
# Uso: se ejecuta solo con el devcontainer, en postCreateCommand.
# Es idempotente: si Flutter o el SDK ya existen, no los vuelve a descargar.

FLUTTER_DIR="$HOME/development/flutter"
ANDROID_SDK_DIR="$HOME/Android/Sdk"
CMDLINE_TOOLS_ZIP="/tmp/commandlinetools-linux.zip"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"

echo "==> Instalando dependencias del sistema..."
sudo apt-get update -y
sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa openjdk-17-jdk

echo "==> Instalando Flutter estable en $FLUTTER_DIR ..."
if [ ! -d "$FLUTTER_DIR" ]; then
  mkdir -p "$HOME/development"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
else
  echo "Flutter ya existe, no se descarga de nuevo."
fi

echo "==> Instalando Android SDK en $ANDROID_SDK_DIR ..."
mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
if [ ! -d "$ANDROID_SDK_DIR/cmdline-tools/latest" ]; then
  curl -L -o "$CMDLINE_TOOLS_ZIP" "$CMDLINE_TOOLS_URL"
  unzip -q -o "$CMDLINE_TOOLS_ZIP" -d "$ANDROID_SDK_DIR/cmdline-tools/tmp"
  mkdir -p "$ANDROID_SDK_DIR/cmdline-tools/latest"
  mv "$ANDROID_SDK_DIR/cmdline-tools/tmp/cmdline-tools/"* "$ANDROID_SDK_DIR/cmdline-tools/latest/"
  rm -rf "$ANDROID_SDK_DIR/cmdline-tools/tmp" "$CMDLINE_TOOLS_ZIP"
else
  echo "Android cmdline-tools ya existe, no se descarga de nuevo."
fi

echo "==> Añadiendo Flutter, Dart y Android SDK al PATH..."
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  touch "$RC"
  grep -q 'development/flutter/bin' "$RC" || cat >> "$RC" <<'EOF'

# Flutter, Dart y Android SDK (App_demo1)
export PATH="$HOME/development/flutter/bin:$HOME/development/flutter/bin/cache/dart-sdk/bin:$HOME/Android/Sdk/cmdline-tools/latest/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
EOF
done

export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$ANDROID_SDK_DIR/cmdline-tools/latest/bin:$ANDROID_SDK_DIR/platform-tools:$PATH"
export ANDROID_HOME="$ANDROID_SDK_DIR"
export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"

echo "==> Aceptando licencias de Android e instalando platform-tools y Android 36..."
yes | sdkmanager --licenses || true
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "build-tools;28.0.3"

echo "==> Configurando Flutter con el Android SDK..."
flutter config --android-sdk "$ANDROID_SDK_DIR" || true

echo "==> Verificación:"
flutter --version
dart --version
flutter doctor
echo "ANDROID_HOME=$ANDROID_HOME"
echo "PATH=$PATH"
echo "==> Listo."
