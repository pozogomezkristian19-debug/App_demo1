#!/usr/bin/env bash
# Build release de Melli-Qui.
# Uso: desde la carpeta del proyecto, corre primero `flutter pub get`
# y luego `bash build-release.sh`.
# Funciona tanto en un Codespace de GitHub como en otra máquina con
# Flutter, JDK 17 y el Android SDK instalados.
set -euo pipefail

# Ir a la carpeta donde está este script (la raíz del proyecto Flutter),
# sin importar desde dónde se lo llame.
cd "$(dirname "$0")"

# Rutas típicas del entorno, solo si existen (en el Codespace Flutter y
# el SDK ya están en el PATH gracias al devcontainer).
if [ -d "$HOME/development/flutter/bin" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
if [ -d "$HOME/Android/Sdk/cmdline-tools/latest/bin" ]; then
  export PATH="$HOME/Android/Sdk/cmdline-tools/latest/bin:$HOME/Android/Sdk/platform-tools:$PATH"
fi
if [ -d /usr/lib/jvm/java-17-openjdk-amd64 ]; then
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
fi
if [ -d "$HOME/Android/Sdk" ]; then
  export ANDROID_HOME=$HOME/Android/Sdk
  export GRADLE_USER_HOME=$HOME/.gradle
fi

# Proxy de salida, solo si el entorno define uno (en el Codespace
# normalmente no hace falta).
if [ -n "${https_proxy:-}" ]; then
  PH=$(echo "$https_proxy" | sed -E 's|.*@([^:]+):[0-9]+$|\1|')
  PP=$(echo "$https_proxy" | sed -E 's|.*:([0-9]+)$|\1|')
  PU=$(echo "$https_proxy" | sed -E 's|http://([^:]+):.*|\1|')
  PW=$(echo "$https_proxy" | sed -E 's|http://[^:]+:([^@]+)@.*|\1|')
  export GRADLE_OPTS="-Dhttps.proxyHost=$PH -Dhttps.proxyPort=$PP -Dhttps.proxyUser=$PU -Dhttps.proxyPassword=$PW -Dhttp.proxyHost=$PH -Dhttp.proxyPort=$PP -Dhttp.proxyUser=$PU -Dhttp.proxyPassword=$PW -Dhttps.nonProxyHosts=localhost -Dhttp.nonProxyHosts=localhost"
fi

# El logo (assets/logo.png) viaja en el repo como texto base64
# (assets/logo.png.b64), porque el conector de GitHub no sube binarios
# por línea de comandos. Si falta el PNG, se reconstruye aquí.
if [ ! -f assets/logo.png ] && [ -f assets/logo.png.b64 ]; then
  base64 -d assets/logo.png.b64 > assets/logo.png
  echo "Logo reconstruido desde assets/logo.png.b64"
fi

# La ilustración de las gemelas (assets/twins.png) viaja igual, como
# assets/twins.png.b64: es la decoración de la bienvenida.
if [ ! -f assets/twins.png ] && [ -f assets/twins.png.b64 ]; then
  base64 -d assets/twins.png.b64 > assets/twins.png
  echo "Gemelas reconstruidas desde assets/twins.png.b64"
fi

# Igual con el logo de WhatsApp (assets/whatsapp.png): viaja como
# assets/whatsapp.png.b64 y se reconstruye aquí antes del build,
# porque pubspec.yaml lo declara como asset y sin el PNG el build falla.
if [ ! -f assets/whatsapp.png ] && [ -f assets/whatsapp.png.b64 ]; then
  base64 -d assets/whatsapp.png.b64 > assets/whatsapp.png
  echo "Logo de WhatsApp reconstruido desde assets/whatsapp.png.b64"
fi

# Cualquier otro binario que viaje como *.b64 (mascotas brenda/britany,
# sonidos, ...) se reconstruye con el mismo mecanismo genérico que el
# workflow de GitHub Actions: si falta el archivo real y existe su .b64,
# se decodifica aquí antes del build.
for b in $(find assets -name "*.b64" 2>/dev/null); do
  real="${b%.b64}"
  if [ ! -f "$real" ]; then
    base64 -d "$b" > "$real"
    echo "Reconstruido: $real desde $b"
  fi
done

# El conector de GitHub sube los binarios como texto base64, asi que el
# jar de Gradle y los iconos de la app llegaron al repo como texto y hay
# que convertirlos a binarios antes de compilar. Si un archivo ya es
# binario de verdad, se deja como esta.
for f in android/gradle/wrapper/gradle-wrapper.jar android/app/src/main/res/mipmap-*/ic_launcher.png; do
  if file "$f" | grep -qE "Zip archive|PNG image"; then
    echo "OK binario: $f"
  else
    base64 -d "$f" > /tmp/restore.bin && mv /tmp/restore.bin "$f"
    echo "Restaurado: $f"
  fi
done

flutter build apk --release

APK=build/app/outputs/flutter-apk/app-release.apk
# Copia con nombre claro junto al proyecto, para subirla o descargarla fácil.
DEST="$(pwd)/melli-qui-release.apk"
cp "$APK" "$DEST"
echo "APK final: $DEST"
ls -lh "$DEST"
sha1sum "$DEST"
