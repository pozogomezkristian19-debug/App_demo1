// Pruebas fix3 (2026-11-10, punto 8): la introducción de
// "Tips de examen" se veía rota en el teléfono del usuario:
// letras ENORMES en rojo, fuente monoespaciada, subrayado doble
// AMARILLO, sobre fondo negro. El título "Tips" también salía en
// rojo con subrayado amarillo, mientras la tarjeta de abajo se veía
// bien.
//
// Causa exacta (confirmada en el fuente del SDK de Flutter,
// packages/flutter/lib/src/material/app.dart): TipsScreen era un
// ListView pelado, sin Scaffold ni Material. Sin Material, un Text
// hereda el DefaultTextStyle de MaterialApp, que es a propósito el
// estilo feo de aviso _errorTextStyle — color 0xD0FF0000 (rojo),
// monoespaciada, 48 px, w900, subrayado doble amarillo
// (0xFFFFFF00) — exactamente lo de la captura. El fondo negro es la
// ventana (la ruta opaca no pinta nada debajo) y las tarjetas se
// veían bien porque cada Card/Material repone su propio bodyMedium.
// La corrección: TipsScreen ahora es Scaffold con AppBar (como
// todas las pantallas de detalle) y la introducción lleva el estilo
// explícito bodyMedium del tema; de paso, todas las demás
// introducciones de Aprender que usaban el mismo patrón sin estilo
// llevan ahora el estilo explícito del tema. Estas pruebas
// comprueban el estilo EFECTIVO (el que pinta RichText) en claro y
// en oscuro: cuerpo 16 Roboto con el color del tema, título de
// AppBar 20 w800, sin subrayado, sin rojo y sin monoespaciada. Las
// pantallas se montan SIN Scaffold exterior a propósito, para que
// un Text sin estilo no quede tapado por el bodyMedium del
// Scaffold (así el test fallaba antes del arreglo: la intro salía
// con 48.0).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/topics.dart';
import 'package:quimica_pura/screens/aprender_screen.dart';
import 'package:quimica_pura/screens/branches_screen.dart';
import 'package:quimica_pura/screens/tips_screen.dart';
import 'package:quimica_pura/screens/topic_detail_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Réplica mínima y fiel del textTheme y la AppBar de MelliQuiApp
/// (main.dart): cuerpo 16 Roboto con el color del tema, título de
/// pantalla 22 y título de AppBar 20 w800.
ThemeData melliTextTheme({required bool dark}) => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0A1F1A) : Colors.white,
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: BrandColors.mintLight,
              onSurface: Color(0xFFE6F4EE),
              surface: Color(0xFF122B24),
            )
          : const ColorScheme.light(
              primary: BrandColors.teal,
              onSurface: BrandColors.ink,
              surface: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            dark ? const Color(0xFF0A1F1A) : Colors.white,
        foregroundColor:
            dark ? const Color(0xFFE6F4EE) : BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: dark ? const Color(0xFFE6F4EE) : BrandColors.ink,
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
            fontSize: 16,
            height: 1.45,
            color:
                dark ? const Color(0xFFE6F4EE) : BrandColors.ink),
        bodyLarge: TextStyle(
            fontSize: 17,
            height: 1.45,
            color:
                dark ? const Color(0xFFE6F4EE) : BrandColors.ink),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color:
                dark ? const Color(0xFFE6F4EE) : BrandColors.ink),
      ).apply(fontFamily: 'Roboto'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
  });

  Future<void> pumpScreen(
      WidgetTester tester, Widget child, bool dark) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliTextTheme(dark: dark),
        home: child,
      ),
    );
    await tester.pump();
  }

  /// Estilo efectivo (el que pinta RichText) de un Text: el RichText
  /// es hijo del Text, así que se busca como descendiente.
  TextStyle effectiveStyle(WidgetTester tester, String text) {
    final rich = tester.widget<RichText>(
      find
          .descendant(
            of: find.text(text),
            matching: find.byType(RichText),
          )
          .first,
    );
    return (rich.text as TextSpan).style!;
  }

  void expectNormalBody(TextStyle style, Color color,
      {String? reason}) {
    expect(style.fontSize, 16, reason: reason);
    expect(style.fontFamily, 'Roboto', reason: reason);
    expect(style.color, color, reason: reason);
    // Sin subrayado: el estilo fusionado pone decoration en
    // TextDecoration.none (nunca underline) y jamás el doble
    // amarillo de la captura rota.
    expect(style.decoration, TextDecoration.none, reason: reason);
    expect(style.decorationStyle,
        isNot(TextDecorationStyle.double), reason: reason);
  }

  void expectNormalTitle(TextStyle style, Color color) {
    expect(style.fontSize, 22);
    expect(style.fontFamily, 'Roboto');
    expect(style.color, color);
    expect(style.decoration, TextDecoration.none);
    expect(style.decorationStyle,
        isNot(TextDecorationStyle.double));
  }

  /// Título de AppBar (20 w800, color del tema): el "Tips" de la
  /// pantalla de Tips vive ahí desde el arreglo.
  void expectAppBarTitle(TextStyle style, Color color) {
    expect(style.fontSize, 20);
    expect(style.fontWeight, FontWeight.w800);
    expect(style.fontFamily, 'Roboto');
    expect(style.color, color);
    // Sin subrayado: null o none (nunca underline); jamás el doble
    // amarillo de la captura rota.
    expect(style.decoration, anyOf(isNull, TextDecoration.none));
    expect(style.decorationStyle,
        isNot(TextDecorationStyle.double));
  }

  const introText =
      'Lo que distingue una respuesta correcta de una «casi»: método, unidades y comprobaciones rápidas.';

  group('Tips de examen: título de AppBar e introducción normales',
      () {
    for (final dark in [false, true]) {
      testWidgets(dark ? 'oscuro' : 'claro', (tester) async {
        await pumpScreen(tester, const TipsScreen(), dark);
        final color =
            dark ? const Color(0xFFE6F4EE) : BrandColors.ink;
        // AppBar presente (antes no había ni Scaffold ni forma de
        // volver) con el título en el estilo normal de AppBar.
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        expectAppBarTitle(
            effectiveStyle(tester, tr('tipsTitle')), color);
        expectNormalBody(effectiveStyle(tester, introText), color);
        // La tarjeta de abajo también es texto normal (título 17 en
        // negrita, cuerpo 16), sin rojo ni subrayado.
        final cardTitle =
            effectiveStyle(tester, 'Método para cualquier problema');
        expect(cardTitle.fontSize, 17);
        expect(cardTitle.fontWeight, FontWeight.bold);
        expect(cardTitle.fontFamily, 'Roboto');
        expect(cardTitle.color, color);
        expect(cardTitle.decoration, TextDecoration.none);
      });
    }
  });

  group('Aprender: título e introducción normales', () {
    for (final dark in [false, true]) {
      testWidgets(dark ? 'oscuro' : 'claro', (tester) async {
        await pumpScreen(tester, const AprenderScreen(), dark);
        final color =
            dark ? const Color(0xFFE6F4EE) : BrandColors.ink;
        expectNormalTitle(
            effectiveStyle(tester, tr('learnTitle')), color);
        expectNormalBody(
            effectiveStyle(tester, tr('learnIntro')), color);
      });
    }
  });

  group('Resúmenes de todos los temas: cuerpo normal', () {
    for (final dark in [false, true]) {
      testWidgets(dark ? 'oscuro' : 'claro', (tester) async {
        final color =
            dark ? const Color(0xFFE6F4EE) : BrandColors.ink;
        for (final topic in topics) {
          await pumpScreen(
              tester, TopicDetailView(topic: topic), dark);
          for (final p in topic.summary) {
            expectNormalBody(
                effectiveStyle(tester, p), color,
                reason: 'tema ${topic.slug}');
          }
        }
      });
    }
  });

  group('Ramas: introducciones con el estilo normal', () {
    for (final dark in [false, true]) {
      testWidgets(dark ? 'oscuro' : 'claro', (tester) async {
        final color =
            dark ? const Color(0xFFE6F4EE) : BrandColors.ink;
        await pumpScreen(tester, const BranchesScreen(), dark);
        expectNormalBody(
            effectiveStyle(tester,
                'La química se divide en ramas. Cada una tiene sus temas, sus fórmulas y sus ejemplos.'),
            color);
        final branch = branches.first;
        await pumpScreen(
            tester, BranchDetailScreen(branch: branch), dark);
        expectNormalBody(
            effectiveStyle(tester, branch.body), color);
      });
    }
  });
}
