# VPN Cuba

Un toque y listo. El usuario solo toca **Conectar**: la app descarga la
lista de servidores gratuitos, prueba los mejores y levanta el túnel.
Sin listas, sin archivos, sin cuentas, sin pagos.

- **Nombre:** VPN Cuba · **Paquete:** `com.kristian.vpncuba` · **Versión:** 1.0.0+1
- **Motor:** `sing_box` (sing-box 1.14.4, VpnService en Android).
  Protocolos: VLESS (Reality/TLS), Trojan, Hysteria2, VMess, Shadowsocks,
  WireGuard. Sin OpenVPN en la v1: un solo motor, más simple.
- **Servidores:** listas públicas gratuitas, en este orden:
  1. `0xRadikal/Free-v2ray-Configs` (`top100.txt`, 100 configs)
  2. `morpheusadam/v2ray-config` (`subs/bundles/best.txt`, 2000 configs)
  La última lista y el último servidor que funcionó se guardan en el
  teléfono, para que el segundo intento sea rápido y para reintentar sin
  internet. Se prefieren VLESS-Reality y Trojan (se disfrazan de HTTPS).
- **Lógica (rápida):** al abrir la app se precarga la lista en
  segundo plano. Al tocar Conectar, primero se prueba el último
  servidor que funcionó SIN esperar la descarga (10 s); solo si
  falla se descarga la lista (8 s por fuente, precargada si está
  fresca) y se prueban hasta 6 servidores de 10 s, en silencio, con
  Reality/Trojan primero. Si el túnel se cae solo, prueba una vez el
  siguiente servidor. Si todo falla: "No se pudo conectar, inténtalo
  de nuevo".
- **Aviso honesto:** solo en el primer inicio y en el icono de info:
  servidores públicos gratuitos, lentos y cambiantes; no usar para
  banca ni contraseñas importantes. Con servidores gratis nadie puede
  prometer 100% siempre: lo que la app sí garantiza es reintento
  automático, recordar el servidor que funcionó y guardar la lista.
  Medido en vivo el 2026-11-15 (red rápida de la VM, no Cuba):
  top100 21 KB en 0,45–0,74 s (100 configs), best.txt 317 KB en
  0,79 s (2000 configs); en Cuba será más lento, por eso los
  tiempos de espera son de 8–10 s.
- **Permiso de VPN (Android):** al tocar Conectar por primera vez,
  Android muestra su diálogo del sistema ("VPN Cuba quiere configurar
  una conexión VPN que le permite supervisar el tráfico de red").
  Verificado en el código del plugin sing_box 1.0.0: `connect()` ya
  pide el permiso solo (`requestPermission: true` → `hasVpnPermission`
  → `requestVpnPermission()` → `VpnService.prepare()` + diálogo del
  sistema, y si se niega lanza `SingBoxPermissionException`), y además
  `_connectFlow` lo pide EXPLÍCITO antes de probar servidores, para
  que el diálogo salga siempre al tocar Conectar. Si se niega, la app
  dice "Necesitas aceptar el permiso de VPN para conectar" y no se
  queda en "Buscando…". El permiso de notificaciones es aparte y la
  VPN funciona igual sin él. El servicio `SingBoxVpnService` lo
  declara el propio plugin en su manifiesto (`BIND_VPN_SERVICE`,
  `foregroundServiceType="systemExempted"`); la app solo repite
  INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE y
  POST_NOTIFICATIONS en su manifiesto.

## Diseño (familia Quemia, identidad propia de VPN)

Lenguaje de familia solo en diseño, sin copiar Quemia y **sin
mellizas**: nada de Brenda/Britany, ni muñequitas, ni sus nombres,
ni su violeta/azul. Identidad propia de VPN: un escudo al conectar.

- **Fuente:** Nunito de Quemia (Regular/SemiBold/Bold/ExtraBold).
- **Colores:** fondo oscuro teal de Quemia (`#0A1F1A`), tarjeta
  `#122B24`, un solo color de acción: teal de Quemia (`#00C2A8`,
  labio `#00A18D`).
- **Botones:** SÓLIDOS estilo Duolingo con labio 4 pt más oscuro,
  SIN gradiente / brillo / sombra borrosa, texto extra-bold en
  mayúsculas (17 pt).
- **Logo:** el anillo orbital de Quemia, en pequeño, en la cabecera.
- **Tono:** amable en español, sin textos técnicos: "Toca Conectar
  y listo", "Buscando el mejor servidor…", "¡Ya estás protegido!".
- **Historial:** el botón "Abrir Quemia" se quitó el 2026-11-15 por
  orden de Kristian: la VPN no enlaza ni abre Quemia.

## Capturas (fotos primero)

Antes de compilar el APK final y antes de cualquier subida, Kristian
revisa las capturas. Se generan con tests de widgets y fuentes reales
(Nunito de Quemia + MaterialIcons del SDK):

```
flutter test --update-goldens test/golden_test.dart
```

- `test/goldens/vpn_desconectado.png` (también en `previews/`)
- `test/goldens/vpn_buscando.png`
- `test/goldens/vpn_conectado.png`

El logo de anillo se precarga con `tester.runAsync(precacheImage)`:
sin `runAsync` el await se cuelga, porque la decodificación necesita
tiempo real, no tiempo falso del test.

## País del servidor

El nombre del servidor rara vez dice el país en palabras ("US 🇺🇸 |
@Raydikalx | 47E914" es lo típico en top100). El detector entiende
banderas emoji (🇺🇸 → EE. UU.), códigos en MAYÚSCULAS ("US", "DE")
y nombres ("Japón", "United States"). No se inventa país de
nombres raros ("@DeltaKroneckerG", "Best-In-01" no es India):
en esos casos la línea de país simplemente no se muestra.

## Compilar

```sh
export GRADLE_USER_HOME=$HOME/.gradle   # el wrapper de Java usa
                                        # user.home=/root si no se pone
export GRADLE_OPTS="-Djava.net.preferIPv4Stack=true"  # localhost
                                        # resuelve a ::1 primero y el
                                        # daemon escucha en 127.0.0.1
flutter analyze
flutter test
flutter build apk --release
```

El APK sale en `build/app/outputs/flutter-apk/app-release.apk`.

Notas de entorno (VM 2026-11-14, que también afectan a Quemia):
- Java resolvía `user.home=/root`, así que el wrapper buscaba
  Gradle en `/root/.gradle` (descarga a medias) en vez de
  `/home/hatch/.gradle` (distribución completa). Con
  `GRADLE_USER_HOME=$HOME/.gradle` usa la caché buena.
- El almacén de confianza Java (`/etc/ssl/certs/java/cacerts`)
  no existía: se regeneró con `update-ca-certificates -f`
  (incluye la CA del proxy de salida). Sin él, Gradle no podía
  descargar plugins (fallo `kotlin-dsl 6.4.2` del script de Flutter).
- La contraseña del proxy en `~/.gradle/gradle.properties` estaba
  desactualizada respecto a la variable de entorno: se actualizó.

## Firma

v1 firmada con claves **debug** (la plantilla de Flutter). El keystore
release #2 de Quemia existe en el workspace, pero sus contraseñas no
están en esta sesión y no se inventa un keystore nuevo: la firma
release se configura cuando Kristian lo apruebe, con sus secretos.

## Pendiente (honesto)

- La conexión real del túnel solo se puede probar en su teléfono en
  Cuba: el build en verde no prueba que un servidor pase por ETECSA.
- La captura "Conectado" usa datos de ejemplo (país EE. UU. e IP
  de documentación 203.0.113.42): el diseño es real, los datos no.
  En la lista real, el país solo se muestra cuando el nombre del
  servidor lo dice claro; en `best.txt` solo 10 de 2000 lo dicen.
