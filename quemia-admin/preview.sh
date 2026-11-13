#!/bin/bash
# Genera los previews PNG en ~/workspace/quemia-admin-previews/.
#
# POR QUÉ así: en este VM, RenderRepaintBoundary.toImage() dentro de un
# flutter_test deja el test colgado al cerrarse (el cuerpo termina en <1 s
# y el PNG ya está escrito, pero el runner nunca recibe "test completado"
# y hay que matarlo; ni image.dispose() lo evita — es un quirk del
# flutter_tester aquí, no de la app). Por eso cada preview se corre en su
# propio proceso y se mata el proceso en cuanto su PNG existe.
# Uso: ./preview.sh   (desde ~/workspace/quemia-admin)

set -u
cd "$(dirname "$0")"
FLUTTER=~/sdks/flutter-3.47.9/bin/flutter
OUT=~/workspace/quemia-admin-previews

for spec in \
  "preview: panel|panel.png" \
  "preview: estadísticas|estadisticas.png" \
  "preview: tabla de posiciones|tabla_posiciones.png" \
  "preview: menú|menu.png" \
  "preview: usuarios|usuarios.png" \
  "preview: detalle de usuario|detalle_usuario.png" \
  "preview: administradores|administradores.png" \
  "preview: ajustes|ajustes.png" \
  "preview: avisos|avisos.png" \
  "preview: niveles|niveles.png" \
  "preview: editor|editor.png" \
  "preview: reportes|reportes.png" \
  "preview: soporte|soporte.png" ; do
  name="${spec%%|*}"
  png="${spec##*|}"
  rm -f "$OUT/$png"
  $FLUTTER test test/preview_test.dart --plain-name "$name" \
    > "/tmp/preview-$png.log" 2>&1 &
  pid=$!
  ok=0
  # Espera hasta 180 s por preview: con la CPU compartida con otro
  # agente, la compilación + precache pueden tardar más de 60 s. El
  # bucle sale en cuanto existe el PNG, así que los previews rápidos
  # no se alargan.
  for i in $(seq 1 90); do
    sleep 2
    if [ -s "$OUT/$png" ]; then ok=1; break; fi
    kill -0 "$pid" 2>/dev/null || break
  done
  # Mata el proceso (y su flutter_tester) aunque el test se haya colgado
  # al cerrarse; el PNG ya está escrito.
  pkill -f "flutter test test/preview_test.dart" 2>/dev/null
  pkill -f "flutter_tester.*quemia-admin" 2>/dev/null
  sleep 2
  if [ "$ok" = 1 ]; then
    echo "OK  $png ($(stat -c%s "$OUT/$png") bytes)"
  else
    echo "FALLO  $png — ver /tmp/preview-$png.log"
  fi
done
