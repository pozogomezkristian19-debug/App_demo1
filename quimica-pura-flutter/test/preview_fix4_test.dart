// Vistas previas de la ronda #4 (Quemia 6.1): una captura por punto.
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix4_*). Viewport
// 360x800 (dpr 2), Roboto real; las oscuras bombean la app real
// (MelliQuiApp) para verificar el _darkTheme() de verdad.
// Los PNG se leen y se verifican a mano antes de informar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/notifications_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Notas que verá Kristian en el diálogo de la 6.1 (su teléfono tiene
/// la 6.0): qué trae esta ronda.
const _updateInfo = UpdateInfo(
  latest: '6.1',
  apkUrl: 'https://example.com/app.apk',
  notes: 'Tabla como en v6, tema oscuro violeta, notificaciones con '
      '"Ir a Ajustes", centro de notificaciones, vidas solo en '
      'niveles y tip del día en el widget.',
  force: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    await NotificationInbox.load();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException
    // (error asíncrono que el test reporta como fallo).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    ProgressService.instance.markElementDayShown();
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    NotificationInbox.resetForTests();
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 360,
    double height = 800,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Calienta la caché de imágenes de los tres acompañantes antes
  /// de la captura: el PNG (1600x1600) se decodifica de forma
  /// asíncrona y, con la caché fría, la primera captura de un
  /// proceso lo pilla sin cargar (círculo vacío en vez de la foto,
  /// como pasó en fix4_niveles_compact). En el teléfono la foto va
  /// empaquetada y sale siempre; el círculo vacío es solo un
  /// artefacto del render, no un bug de la app.
  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await precacheImage(AssetImage(companionAsset(c)), ctx);
    }
    await tester.pump();
  }

  Future<void> pumpTabla(
    WidgetTester tester, {
    double width = 360,
    double height = 800,
  }) async {
    await setPhone(tester, width: width, height: height);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: TablaScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Calentamiento: decodifica las imágenes de los acompañantes ANTES
  // de la primera captura (patrón de preview_fix2_test.dart).
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(
                  image: AssetImage('assets/brenda.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/britany.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/kristian.png'),
                  width: 40,
                  height: 40),
              // El logo de WhatsApp del botón de Soporte en Cuenta.
              Image(
                  image: AssetImage('assets/whatsapp.png'),
                  width: 40,
                  height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in ['brenda', 'britany', 'kristian']) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  testWidgets('fix4_tabla_400: tabla completa a 400 dp, sin scroll',
      (tester) async {
    await pumpTabla(tester, width: 400);
    await shot(tester, 'fix4_tabla_400.png');
  });

  testWidgets('fix4_tabla_320: teléfono angosto, todas las filas',
      (tester) async {
    await pumpTabla(tester, width: 320, height: 2000);
    await shot(tester, 'fix4_tabla_320.png');
  });

  testWidgets('fix4_tabla_chips: fila de chips con fade a la derecha',
      (tester) async {
    await pumpTabla(tester);
    await shot(tester, 'fix4_tabla_chips.png');
  });

  Future<void> pumpDark(
    WidgetTester tester, {
    required String accent,
  }) async {
    await UserPrefs.saveThemeMode('oscuro');
    UserPrefs.isDark = true;
    UserPrefs.themeAccent = accent;
    UserPrefs.themeAccentNotifier.value = accent;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  testWidgets('fix4_dark_violet: tema oscuro + Violeta', (tester) async {
    await pumpDark(tester, accent: 'violeta');
    await shot(tester, 'fix4_dark_violet.png');
  });

  testWidgets('fix4_dark_green: tema oscuro + Verde', (tester) async {
    await pumpDark(tester, accent: 'verde');
    await shot(tester, 'fix4_dark_green.png');
  });

  testWidgets(
      'fix4_niveles_no_review: Niveles con 1 error, sin la '
      'tarjeta de repaso', (tester) async {
    ProgressService.instance.addFailed(const FailedEntry(
      id: 'preview-review-1',
      topic: 'bach-estequiometria',
      question: 'Pregunta de prueba',
      level: 1,
    ));
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await warmCompanions(tester);
    await shot(tester, 'fix4_niveles_no_review.png');
  });

  testWidgets(
      'fix4_reto_points: resultado del Reto con puntos, sin '
      'vidas en juego', (tester) async {
    const items = [
      QuizQuestion(
        topic: 'tabla',
        question: 'Pregunta fácil de prueba',
        options: ['A fácil', 'B fácil', 'C fácil', 'D fácil'],
        answer: 0,
        explanation: 'Por qué la A.',
        difficulty: 1,
      ),
      QuizQuestion(
        topic: 'tabla',
        question: 'Pregunta media de prueba',
        options: ['A media', 'B media', 'C media', 'D media'],
        answer: 1,
        explanation: 'Por qué la B.',
        difficulty: 2,
      ),
      QuizQuestion(
        topic: 'tabla',
        question: 'Pregunta difícil de prueba',
        options: ['A difícil', 'B difícil', 'C difícil', 'D difícil'],
        answer: 2,
        explanation: 'Por qué la C.',
        difficulty: 3,
      ),
    ];
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SimpleQuizRunner(
            title: 'Reto',
            items: items,
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    Future<void> answer(String option) async {
      await tester.tap(find.text(option));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await answer('A fácil'); // +3
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await answer('A media'); // mal: −8
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await answer('C difícil'); // +8
    await tester.tap(find.text('Resultado'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix4_reto_points.png');
  });

  testWidgets(
      'fix4_update_dialog: diálogo de la 6.1 (lo que verá el '
      'teléfono con la 6.0)', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    final context = tester.element(find.byType(Scaffold).first);
    UpdateCheckService.showUpdateDialog(context, _updateInfo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'fix4_update_dialog.png');
  });

  testWidgets(
      'fix4_update_check_button: Cuenta con "Buscar '
      'actualización"', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const [],
          ),
        ),
      ),
    );
    // Sin pumpAndSettle: el corazón de la tarjeta de estadísticas
    // late sin parar (PulseWidget repite cada 1200 ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Buscar actualización'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix4_update_check_button.png');
  });

  testWidgets('fix4_cuenta_soporte: Cuenta con la fila de Soporte al final',
      (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const [],
          ),
        ),
      ),
    );
    // Sin pumpAndSettle: el corazón de la tarjeta de estadísticas
    // late sin parar (PulseWidget repite cada 1200 ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Soporte'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix4_cuenta_soporte.png');
  });

  testWidgets(
      'fix4_inbox_v2: bandeja rediseñada (tintes por tipo, sin leer '
      'en negrita, leída atenuada)', (tester) async {
    // Fecha fija y VIEJA (8/11/2026, 10:30): la hora de las entradas
    // no cambia entre corridas y el golden es estable. Tiene que ser
    // anterior a "ayer": si fuera hoy saldría "hoy, HH:MM" y mañana
    // "ayer, HH:MM"; con fecha vieja siempre sale "8/11/2026, 10:30".
    final at = DateTime(2026, 11, 8, 10, 30);
    await NotificationInbox.add(
      id: 'update-6.1',
      kind: InboxKind.update,
      title: 'Hay una nueva actualización que aún no has descargado',
      body: 'Versión 6.1\nTabla como antes, violeta en oscuro, centro '
          'de notificaciones, vidas solo en niveles, tip en el widget.',
      createdAt: at,
      data: const {
        'latest': '6.1',
        'apk_url': '',
        'notes': 'Tabla como antes, violeta en oscuro, centro de '
            'notificaciones, vidas solo en niveles, tip en el widget.',
        'force': false,
      },
    );
    await NotificationInbox.add(
      id: 'reminder-1',
      kind: InboxKind.reminder,
      title: 'Recordatorio de estudio',
      body: 'Toca repasar Estequiometría y el mol, tu tema más flojo.',
      createdAt: at,
    );
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: NotificationsScreen(onOpenScreen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // Una entrada nueva DESPUÉS de abrir la bandeja (las de arriba
    // ya se marcaron leídas al abrir): arriba queda una sin leer
    // (negrita, tinte fuerte, puntito) y abajo las leídas atenuadas.
    await NotificationInbox.add(
      id: 'reminder-2',
      kind: InboxKind.reminder,
      title: 'Recordatorio de estudio',
      body: 'Toca repasar Disoluciones, tu tema más flojo.',
      createdAt: at,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix4_inbox_v2.png');
  });

  testWidgets('fix4_inbox_bell: campana con el numerito (2 sin leer)',
      (tester) async {
    final at = DateTime(2026, 11, 8, 10, 30);
    await NotificationInbox.add(
      id: 'update-6.1',
      kind: InboxKind.update,
      title: 'Hay una nueva actualización que aún no has descargado',
      body: 'Versión 6.1',
      createdAt: at,
    );
    await NotificationInbox.add(
      id: 'reminder-1',
      kind: InboxKind.reminder,
      title: 'Recordatorio de estudio',
      body: 'Toca repasar.',
      createdAt: at,
    );
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await warmCompanions(tester);
    await shot(tester, 'fix4_inbox_bell.png');
  });

  testWidgets(
      'fix4_niveles_compact: pregunta del día ancha con la foto del '
      'acompañante dentro, sin "te acompaña"', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await warmCompanions(tester);
    await shot(tester, 'fix4_niveles_compact.png');
  });

  testWidgets(
      'fix4_niveles_compact_dark: pregunta del día ancha con la foto '
      'del acompañante dentro, en oscuro violeta', (tester) async {
    await pumpDark(tester, accent: 'violeta');
    await warmCompanions(tester);
    await shot(tester, 'fix4_niveles_compact_dark.png');
  });

  testWidgets(
      'fix4_niveles_sin_pregunta: Niveles con la pregunta del día ya '
      'contestada hoy (retoque final): la tarjeta desaparece y todo '
      'lo de abajo sube', (tester) async {
    ProgressService.instance.recordQotd(DateTime.now());
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await warmCompanions(tester);
    await shot(tester, 'fix4_niveles_sin_pregunta.png');
  });

  testWidgets(
      'fix4_drawer: menú con el simulador en Referencia, arriba de '
      'Tablas de referencia', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    // El toque en el botón del menú no se completa en el binding
    // de tests (ver test/fix4_drawer_sim_test.dart): se abre por
    // API; el contenido y la navegación sí se verifican.
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // El Scrollable del ListView del menú (no el del TextField de
    // búsqueda, que también es un Scrollable dentro del Drawer).
    await tester.scrollUntilVisible(
      find.text(tr('labSimTitle')),
      200,
      scrollable: find.descendant(
        of: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix4_drawer.png');
  });

  testWidgets('fix4_topbar: vidas + repaso + campana, misma separación',
      (tester) async {
    ProgressService.instance.addFailed(const FailedEntry(
      id: 'preview-review-1',
      topic: 'bach-estequiometria',
      question: 'Pregunta de prueba',
      level: 1,
    ));
    await NotificationInbox.add(
      id: 'reminder-1',
      kind: InboxKind.reminder,
      title: 'Recordatorio de estudio',
      body: 'Toca repasar.',
    );
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await shot(tester, 'fix4_topbar.png');
  });

  testWidgets('fix4_widget_tip: réplica del widget con el tip del día',
      (tester) async {
    // Réplica 1:1 del layout nativo (melli_qui_widget.xml): fondo
    // noche #0A1628, título blanco 18, pregunta #D9D2F2 14, tip
    // ámbar claro #FDE68A 14 (máx. 3 líneas), fila Racha/Vidas/
    // Puntos (menta, ámbar, blanco, 13 en negrita). El XML nativo
    // no se puede renderizar en el sandbox; la réplica usa sus
    // mismos textos de ejemplo (tools:text) y colores literales.
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFE9E9E9),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quemia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '¿Cuál es la masa molar del ácido sulfúrico?',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFD9D2F2),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  // El tip sale como lo guarda el servicio (las
                  // flechas "→" del banco se sustituyen por "a" al
                  // guardar para el widget, para no arriesgar un
                  // glifo ausente en la fuente del sistema).
                  Text(
                    'Tip: Convierte todo a las unidades del SI antes '
                    'de sustituir: mL a L, °C a K, g a mol.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Racha: 3',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Vidas: 5/5',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Puntos: 120',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix4_widget_tip.png');
  });
}
