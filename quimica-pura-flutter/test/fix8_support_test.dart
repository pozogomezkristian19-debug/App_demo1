// Ventanita de Soporte (Quemia 7.0, Kristian 09:52): la fila de
// Soporte de Cuenta abre la ventanita dentro de la app (NO WhatsApp
// directo), el envío sin internet no da error (el mensaje queda
// encolado y se muestra "Se enviará solo cuando tengas internet"),
// la opción de WhatsApp solo aparece con el interruptor remoto
// encendido, y la fila de Acerca de muestra el número remoto (por
// defecto +5356519431).
//
// La UI se prueba contra un fake del contrato de SupportService
// (sendMessage, watchMyMessages, fetchMyMessages,
// fetchSupportSettings, pendingMessages, pendingCount,
// listenForReplies, checkRepliesNow, retryPendingSupport,
// resetForTests). El servicio real (Firestore) NO queda probado
// aquí — ver el informe final.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/support_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/support_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'test_helpers.dart';

/// Fake del contrato de SupportService: hilo en memoria, ajustes
/// inyectables y envío que puede fallar (sin internet).
class FakeSupportService implements SupportService {
  FakeSupportService({SupportSettings? settings})
      : settings = settings ??
            const SupportSettings(
                supportNumber: '+5356519431', showWhatsApp: false);

  List<SupportMessage> messages = [];
  List<SupportMessage> queued = [];
  SupportSettings settings;
  var failSend = false;
  final sent = <String>[];
  final _ctrl = StreamController<List<SupportMessage>>.broadcast();

  SupportMessage msg(
    String id,
    String text, {
    String? reply,
    DateTime? at,
  }) =>
      SupportMessage(
        id: id,
        authorUid: 'uid-kristian',
        username: 'kristian',
        message: text,
        createdAt: at ?? DateTime(2026, 11, 11, 10, 0),
        status: reply == null ? 'abierto' : 'respondido',
        reply: reply,
        replyAt: reply == null ? null : DateTime(2026, 11, 11, 11, 0),
      );

  @override
  Future<bool> sendMessage(String text) async {
    if (failSend) {
      queued.add(msg(
        'pending-${queued.length}',
        text,
        at: DateTime.now(),
      ));
      return false;
    }
    sent.add(text);
    messages.insert(0, msg('m${messages.length}', text, at: DateTime.now()));
    _ctrl.add(List.unmodifiable(messages));
    return true;
  }

  @override
  Future<List<SupportMessage>> fetchMyMessages() async =>
      List.unmodifiable(messages);

  @override
  Stream<List<SupportMessage>> watchMyMessages() async* {
    yield List.unmodifiable(messages);
    yield* _ctrl.stream;
  }

  @override
  Future<SupportSettings> fetchSupportSettings() async => settings;

  @override
  Future<List<SupportMessage>> pendingMessages() async =>
      List.unmodifiable(queued);

  @override
  Future<int> pendingCount() async => queued.length;

  @override
  void listenForReplies() {}

  @override
  Future<void> checkRepliesNow() async {}

  @override
  Future<int> retryPendingSupport() async => 0;

  @override
  void resetForTests() {}
}

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (m) async => null);
    AnalyticsSync.resetForTests();
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
  });

  Future<void> pumpSupport(
    WidgetTester tester,
    FakeSupportService fake, {
    bool isGoogleLinked = true,
  }) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: SupportScreen(
          isGoogleLinked: isGoogleLinked,
          service: fake,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: HomeScreen(
          isDark: false,
          onToggleTheme: () {},
          onTrackChanged: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Abre la hoja "Acerca de" desde la fila de Cuenta.
  Future<void> openAboutSheet(WidgetTester tester) async {
    await tester.tap(find.text(tr('accountTitle')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text(tr('accountAbout')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(tr('accountAbout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('ventanita de Soporte (7.0, 09:52)', () {
    testWidgets('el hilo muestra mis mensajes y la respuesta del admin',
        (tester) async {
      final fake = FakeSupportService();
      fake.messages = [
        fake.msg(
          'm1',
          'No me sale el balanceo',
          reply: 'Revisa los coeficientes del oxígeno primero.',
        ),
        fake.msg('m2', 'Hola, tengo una duda'),
      ];
      await pumpSupport(tester, fake);
      expect(find.text('No me sale el balanceo'), findsOneWidget);
      expect(find.text('Revisa los coeficientes del oxígeno primero.'),
          findsOneWidget);
      expect(find.text(tr('supportReplyTitle')), findsOneWidget);
      expect(find.text('Hola, tengo una duda'), findsOneWidget);
      // Estado: el respondido dice "Respondido", el abierto "Abierto".
      expect(find.textContaining(tr('supportAnswered')), findsOneWidget);
      expect(find.textContaining(tr('supportOpen')), findsOneWidget);
    });

    testWidgets('enviar: el mensaje aparece en el hilo al instante',
        (tester) async {
      final fake = FakeSupportService();
      await pumpSupport(tester, fake);
      await tester.enterText(
          find.byType(TextField), 'Mi duda nueva de estequiometría');
      await tester.pump();
      await tester.tap(find.byWidgetPredicate((w) =>
          w is LucideIcon && w.icon == LucideIcons.arrowRight));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mi duda nueva de estequiometría'), findsOneWidget);
      expect(fake.sent, ['Mi duda nueva de estequiometría']);
    });

    testWidgets(
        'sin internet: enviar no da error, queda en cola y se ve la '
        'línea tranquila', (tester) async {
      final fake = FakeSupportService()..failSend = true;
      await pumpSupport(tester, fake);
      await tester.enterText(find.byType(TextField), 'Duda sin internet');
      await tester.pump();
      await tester.tap(find.byWidgetPredicate((w) =>
          w is LucideIcon && w.icon == LucideIcons.arrowRight));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Sin diálogo de error ni rojo: el SnackBar trae la línea
      // tranquila y el mensaje encolado la lleva en su estado.
      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.queued.length, 1);
      expect(find.text('Duda sin internet'), findsOneWidget);
      // La línea tranquila sale dos veces: en el estado del mensaje
      // encolado (con la fecha) y en el SnackBar.
      expect(find.textContaining(tr('supportQueued')), findsNWidgets(2));
    });

    testWidgets('la opción de WhatsApp NO aparece con el interruptor '
        'apagado', (tester) async {
      final fake = FakeSupportService()
        ..settings = const SupportSettings(
            supportNumber: '+53 5 9999999', showWhatsApp: false);
      await pumpSupport(tester, fake);
      expect(find.textContaining('¿Prefieres WhatsApp?'), findsNothing);
    });

    testWidgets('la opción de WhatsApp aparece con el interruptor '
        'encendido y abre wa.me con el número remoto', (tester) async {
      final fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      final fake = FakeSupportService()
        ..settings = const SupportSettings(
            supportNumber: '+53 5 9999999', showWhatsApp: true);
      await pumpSupport(tester, fake);
      expect(
        find.text('¿Prefieres WhatsApp? Escríbenos al +53 5 9999999'),
        findsOneWidget,
      );
      await tester.tap(
          find.text('¿Prefieres WhatsApp? Escríbenos al +53 5 9999999'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fakeLauncher.launched, ['https://wa.me/5359999999']);
    });

    testWidgets('sin Google: solo la puerta, con el texto y el botón',
        (tester) async {
      final fake = FakeSupportService();
      await pumpSupport(tester, fake, isGoogleLinked: false);
      expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
      expect(find.text(tr('googleContinue')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Acerca de: la fila muestra el número remoto', () {
    testWidgets('con número remoto, muestra ese número', (tester) async {
      final repo = InMemoryAnalyticsRepository()
        ..settings = {
          'supportWhatsAppNumber': '+53 5 9999999',
          'showWhatsAppInSupport': true,
        };
      AnalyticsSync.setRepositoryForTests(repo);
      AnalyticsSync.markFirebaseReady();
      await pumpHome(tester);
      await openAboutSheet(tester);
      expect(find.text('${tr('phoneWord')}: +53 59999999'), findsOneWidget);
    });

    testWidgets('sin remoto (sin internet), muestra el número por defecto',
        (tester) async {
      await pumpHome(tester);
      await openAboutSheet(tester);
      expect(find.text('${tr('phoneWord')}: +53 56519431'), findsOneWidget);
    });
  });
}
