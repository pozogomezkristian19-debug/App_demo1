# Melli-Qui (Química Pura — Universidad, Flutter)

App de química pura para universidad, basada en la app web
«Aplicación de Química Pura Instalable» de Kristian Pozo Gómez.
La app se llama **Melli-Qui** (regalo para su novia, melliza).
Logo circular en `assets/logo-circular.png`: dice «Química Pura»
con dos muñequitas gemelas detrás. El logo se ve en la barra
superior de todas las secciones y en la pantalla Resolver.

## Secciones (barra inferior, sin menú hamburguesa)

1. **Resolver** — 7 solucionadores paso a paso: masa molar (con
   paréntesis, p. ej. `Ca(OH)2`, `Al2(SO4)3`), masa ⇄ moles,
   molaridad, dilución C₁V₁ = C₂V₂, pH/pOH, gas ideal PV = nRT y
   reactivo limitante.
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

## Cómo correrla

```bash
cd quimica-pura-flutter
flutter pub get   # no hay dependencias externas, funciona sin conexión
flutter run
```

En el Codespace de App_demo1 (Flutter 3.47.9, Android SDK 36)
basta con `flutter run` o `flutter build apk --release`.

## Notas

- Sin dependencias externas: el progreso (temas dominados y mejor
  puntuación) se guarda en memoria durante la sesión, en
  `lib/services/progress.dart`. Si se quiere persistencia entre
  visitas, ahí es donde se conectaría `shared_preferences`, sin
  tocar las pantallas.
- Tema oscuro azul/teal, diseño mobile-first, texto grande y legible.
- El proyecto está en GitHub, en el repo App_demo1
  (pozogomezkristian19-debug/App_demo1), en `quimica-pura-flutter/`.

## Archivos

- `pubspec.yaml`
- `lib/main.dart` — MaterialApp, tema oscuro, NavigationBar inferior con 5 destinos
- `lib/models.dart` — ChemicalElement, StudyTopic, QuizQuestion, ExamTip
- `lib/data/periodic_table.dart` — 118 elementos + masas atómicas
- `lib/data/topics.dart` — 6 temas + 10 tips + formulario
- `lib/data/questions.dart` — 108 preguntas (24 originales + 84 nuevas)
- `lib/services/chemistry.dart` — cálculo de masa molar con paréntesis
- `lib/services/progress.dart` — progreso en memoria
- `lib/screens/resolver_screen.dart`
- `lib/screens/aprender_screen.dart`
- `lib/screens/tabla_screen.dart`
- `lib/screens/practicar_screen.dart`
- `lib/screens/tips_screen.dart`
