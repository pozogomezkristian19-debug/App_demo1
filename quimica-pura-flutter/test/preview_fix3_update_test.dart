// Vistas previas de la ronda fix3, punto 20 (aviso de actualización):
// el diálogo REAL (fondo blanco, acento teal) sobre la app real, y
// réplicas fieles de las dos notificaciones que la app manda al
// sistema: la descarga con su barra de progreso verde y el
// recordatorio "Hay una actualización pendiente". La notificación real
// del sistema no se puede capturar en un test: la réplica usa el
// mismo icono pequeño (campana blanca, que Android NO pinta como
// cuadrado negro), el mismo color teal #00C2A8, los mismos textos en
// el idioma del usuario y, en el recordatorio, la gemela del día como
// icono grande, igual que los recordatorios de repaso.
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix3_update_*).
// Viewport 360x800 (dpr 2), Roboto real.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

const _updateInfo = UpdateInfo(
  latest: '6.1',
  apkUrl: 'https://example.com/app.apk',
  notes: 'Diseño más limpio en Niveles, niveles nuevos de Orgánica y '
      'el simulador de laboratorio más realista.',
  force: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = true;
    UserPrefs.isDark = false;
    ProgressService.instance.markElementDayShown();
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
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

  // Calentamiento: decodifica las imágenes de los acompañantes
  // (Brenda, Britany, Kristian) ANTES de la primera captura, con
  // runAsync + precacheImage. Sin esto, con solo hacer pump la
  // decodificación seguía pendiente al capturar y el avatar del
  // acompañante detrás del diálogo y la Brenda grande del
  // recordatorio salían vacíos (patrón de preview_fix2_test.dart).
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(image: AssetImage('assets/brenda.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/britany.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/kristian.png'),
                  width: 40, height: 40),
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

  testWidgets('fix3_update_dialog: diálogo blanco con acento teal',
      (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    // El diálogo REAL de la actualización (el mismo que sale al
    // abrir la app cuando version.json trae una versión mayor).
    // El contexto debe ser de un widget DENTRO de MaterialApp (no de
    // MaterialApp mismo: su contexto queda por encima de las
    // Localizations que inserta, y showDialog las necesita).
    final context = tester.element(find.byType(Scaffold).first);
    UpdateCheckService.showUpdateDialog(context, _updateInfo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'fix3_update_dialog.png');
  });

  testWidgets(
      'fix3_update_notification_progress: descarga con barra verde',
      (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _NotificationShadeMock(
          title: 'Descargando Quemia',
          body: 'Versión 6.1 · 45%',
          progress: 0.45,
          largeIconAsset: null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'fix3_update_notif.png');
  });

  testWidgets('fix3_update_reminder: "Hay una actualización pendiente"',
      (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _NotificationShadeMock(
          title: 'Quemia',
          body: 'Hay una actualización pendiente',
          progress: null,
          largeIconAsset: 'assets/brenda.png',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'fix3_update_reminder.png');
  });
}

/// Réplica fiel de cómo se ve la notificación en el teléfono: tarjeta
/// blanca sobre el fondo gris del panel de notificaciones, icono
/// pequeño (campana teal, la silueta blanca que Android pinta con el
/// color de acento), nombre de la app, título en negrita, texto, y
/// (solo en el recordatorio) la gemela del día como icono grande a la
/// derecha; (solo en la descarga) la barra de progreso teal.
class _NotificationShadeMock extends StatelessWidget {
  const _NotificationShadeMock({
    required this.title,
    required this.body,
    required this.progress,
    required this.largeIconAsset,
  });

  final String title;
  final String body;
  final double? progress;
  final String? largeIconAsset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E9E9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 0),
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LucideIcon(
                      LucideIcons.bell,
                      size: 17,
                      color: BrandColors.teal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Quemia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '·  ahora',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(),
                    if (largeIconAsset != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          largeIconAsset!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: BrandColors.ink.withValues(alpha: 0.85),
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor:
                          BrandColors.teal.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        BrandColors.teal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
