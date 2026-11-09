#!/usr/bin/env bash
# Build release de Melli-Qui + copia del APK.
# Requisito previo: en Muse, Ajustes -> Permisos -> Direct network protocols,
# "other_tcp" debe estar en Ask (o permitido). Sin eso, el cliente Gradle
# (Java) no puede hablar con su daemon por TCP loopback y el build falla con
# "Could not dispatch a message to the daemon".
# Uso: bash build-release.sh   (desde cualquier directorio)
set -euo pipefail

export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/cmdline-tools/latest/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=$HOME/Android/Sdk
export GRADLE_USER_HOME=$HOME/.gradle

# Proxy de salida (se lee del entorno en tiempo de ejecución, no se guarda nada).
PH=$(echo "$https_proxy" | sed -E 's|.*@([^:]+):[0-9]+$|\1|')
PP=$(echo "$https_proxy" | sed -E 's|.*:([0-9]+)$|\1|')
PU=$(echo "$https_proxy" | sed -E 's|http://([^:]+):.*|\1|')
PW=$(echo "$https_proxy" | sed -E 's|http://[^:]+:([^@]+)@.*|\1|')
export GRADLE_OPTS="-Dhttps.proxyHost=$PH -Dhttps.proxyPort=$PP -Dhttps.proxyUser=$PU -Dhttps.proxyPassword=$PW -Dhttp.proxyHost=$PH -Dhttp.proxyPort=$PP -Dhttp.proxyUser=$PU -Dhttp.proxyPassword=$PW -Dhttps.nonProxyHosts=localhost -Dhttp.nonProxyHosts=localhost"

cd ~/workspace/quimica-pura-flutter

# El logo (assets/logo.png) viaja en el repo como texto base64
# (assets/logo.png.b64), porque el conector de GitHub no sube binarios
# grandes por línea de comandos. Si falta el PNG, se reconstruye aquí.
if [ ! -f assets/logo.png ] && [ -f assets/logo.png.b64 ]; then
  base64 -d assets/logo.png.b64 > assets/logo.png
  echo "Logo reconstruido desde assets/logo.png.b64"
fi

# Igual con el logo de WhatsApp (assets/whatsapp.png): viaja como
# assets/whatsapp.png.b64 y se reconstruye aquí antes del build,
# porque pubspec.yaml lo declara como asset y sin el PNG el build falla.
if [ ! -f assets/whatsapp.png ] && [ -f assets/whatsapp.png.b64 ]; then
  base64 -d assets/whatsapp.png.b64 > assets/whatsapp.png
  echo "Logo de WhatsApp reconstruido desde assets/whatsapp.png.b64"
fi

flutter build apk --release

APK=build/app/outputs/flutter-apk/app-release.apk
DEST=~/workspace/your_files/melli-qui/melli-qui-release.apk
cp "$APK" "$DEST"
echo "APK final: $DEST"
ls -lh "$DEST"
sha1sum "$DEST"
