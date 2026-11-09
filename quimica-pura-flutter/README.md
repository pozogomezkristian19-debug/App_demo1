# Melli-Qui (Química Pura — Universidad, Flutter)

App de química pura para universidad, basada en la app web
«Aplicación de Química Pura Instalable» de Kristian Pozo Gómez.
La app se llama **Melli-Qui** (regalo para su novia, melliza).
Logo cuadrado en `assets/logo.png`: fondo marrón con dos
muñequitas gemelas grandes y el texto «Química Pura» y
«MELLI-QUI». El logo NO es circular: en el teléfono los iconos
son medio cuadrados. El logo se ve en la barra superior de
todas las secciones y en la pantalla Resolver.

## Bienvenida (solo la primera vez)

Al instalarla, la app muestra varias pantallas de bienvenida:
la primera dice «Bienvenidos» en grande y «Químic@» debajo,
y se avanza con el botón «Siguiente». En la última se pide el
nombre de usuario y el género, con el botón «Finalizar» abajo.
El nombre y el género se guardan en el teléfono, sin internet,
y cada vez que entras la app te saluda «Bienvenida [nombre]»
o «Bienvenido [nombre]» según el género.

## Secciones (barra inferior, sin menú hamburguesa)

1. **Resolver** — 7 solucionadores paso a paso, organizados en
   4 grupos: Cantidad de sustancia (masa molar con paréntesis,
   p. ej. `Ca(OH)2`, `Al2(SO4)3`, y masa ⇄ moles),
   Disoluciones (molaridad y dilución C₁V₁ = C₂V₂), Ácidos y
   bases (pH/pOH) y Gases y reacciones (gas ideal PV = nRT y
   reactivo limitante).
2. **Aprender** — 6 temas (estequiometría, gases, disoluciones,
   ácido-base, equilibrio, termoquímica y cinética) con resumen,
   fórmulas clave, ejemplo resuelto, errores frecuentes y tip de
   examen. Se pueden marcar como dominados. Incluye el formulario
   rápido completo.
3. **Tabla** — Tabla periódica interactiva con los 118 elementos
   (símbolo, nombre, masa, grupo, periodo, bloque, categoría),
   búsqueda, filtro por categoría y ficha al tocar un elemento.
4. **Practicar** — **108 preguntas únicas** en español, 4 opciones
   cada una, con explicación inmediata. Tests por tema y examen
   mixto de 24 preguntas, con preguntas y opciones barajadas,
   corrección inmediata y mejor puntuación guardada.
5. **Tips** — Tips de cálculo, método y estrategia de examen.

## Modo claro / oscuro

Hay un botoncito en la barra superior: una lunita con nubes en
modo oscuro y el sol en modo claro. El tema se guarda en el
teléfono, sin internet.

## Cómo correrla

```bash
cd quimica-pura-flutter
flutter pub get
flutter run
```

En el Codespace de App_demo1 (Flutter 3.47.9, Android SDK 36)
basta con `flutter run` o `flutter build apk --release`.

Nota: el logo (`assets/logo.png`) viaja en el repo como texto
base64 en `assets/logo.png.b64`, porque el conector de GitHub no
sube archivos binarios grandes. Antes del primer build, si falta
el PNG, reconstrúyelo con:

```bash
base64 -d assets/logo.png.b64 > assets/logo.png
```

El script `build-release.sh` ya hace ese paso solo.

Para compilar en release aquí mismo hay un script listo:

```bash
bash build-release.sh
```

## Notas

- El nombre, el género y el tema claro/oscuro se guardan en el
  teléfono con `shared_preferences` (`lib/services/user_prefs.dart`),
  sin internet. El progreso (temas dominados y mejor puntuación)
  se guarda en memoria durante la sesión, en
  `lib/services/progress.dart`.
- Tema oscuro azul/teal y tema claro crema, diseño mobile-first,
  texto grande y legible.
- El proyecto está en GitHub, en el repo App_demo1
  (pozogomezkristian19-debug/App_demo1), en `quimica-pura-flutter/`.

## Archivos

- `pubspec.yaml` — depende de `shared_preferences`
- `lib/main.dart` — MaterialApp, temas claro/oscuro, NavigationBar inferior con 5 destinos, saludo
- `lib/models.dart` — ChemicalElement, StudyTopic, QuizQuestion, ExamTip
- `lib/data/periodic_table.dart` — 118 elementos + masas atómicas
- `lib/data/topics.dart` — 6 temas + 10 tips + formulario
- `lib/data/questions.dart` — 108 preguntas (24 originales + 84 nuevas)
- `lib/services/chemistry.dart` — cálculo de masa molar con paréntesis
- `lib/services/user_prefs.dart` — nombre, género, onboarding y tema, sin internet
- `lib/services/progress.dart` — progreso en memoria
- `lib/screens/onboarding_screen.dart` — bienvenida de 5 pantallas
- `lib/screens/resolver_screen.dart` — 7 solucionadores en 4 grupos
- `lib/screens/aprender_screen.dart`
- `lib/screens/tabla_screen.dart`
- `lib/screens/practicar_screen.dart`
- `lib/screens/tips_screen.dart`
- `assets/logo.png` — logo cuadrado, fondo marrón, mellizas grandes
- `build-release.sh` — compila el APK en release y lo copia a `~/workspace/your_files/melli-qui/`
