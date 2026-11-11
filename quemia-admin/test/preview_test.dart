// Previews: renderiza cada pantalla con datos falsos y guarda PNG en
// ~/workspace/quemia-admin-previews/ para revisión visual.
//
// Ejecutar: flutter test test/preview_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/design.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

const _outDir = '/home/hatch/workspace/quemia-admin-previews';

Future<void> _savePreview(
  WidgetTester tester,
  String name,
  Widget screen, {
  /// Acción opcional antes de capturar (p. ej. hacer scroll hasta una
  /// sección bajo el pliegue). Corre después de los pumps y el precache.
  Future<void> Function(WidgetTester tester)? onReady,
}) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: quemiaAdminTheme(),
      // El Scaffold es necesario: varias pantallas (p. ej. Usuarios con
      // su TextField de búsqueda) exigen un ancestro Material, y en la
      // app real siempre cuelgan del Scaffold de HomeShell. Sin él, el
      // preview se rompe con "No Material widget found". Además da el
      // fondo claro real (0xFFF7F9F9) en vez del negro del canvas.
      home: RepaintBoundary(
        key: key,
        child: Scaffold(body: screen),
      ),
    ),
  );
  // Pumps acotados en vez de pumpAndSettle: los fakes completan en el
  // acto, y 3 pumps bastan para que FutureBuilder pinte los datos.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  // Las imágenes (avatar_default.png) cargan de forma asíncrona: sin
  // precache, los avatares salen como círculos vacíos en el PNG. La
  // decodificación de verdad necesita runAsync: sin él, precacheImage
  // se queda colgado para siempre en este entorno (la zona async falsa
  // del test bloquea el trabajo real del decodificador). No es un
  // problema de la app real (en el teléfono el asset carga al abrir
  // la pantalla), solo del render de previews.
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/avatar_default.png'),
      tester.element(find.byType(MaterialApp).first),
    );
  });
  await tester.pump(const Duration(milliseconds: 100));
  if (onReady != null) {
    await onReady(tester);
    await tester.pump(const Duration(milliseconds: 100));
  }

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_outDir/$name');
  // IO SÍNCRONO a propósito: el IO asíncrono (create/writeAsBytes) se
  // queda colgado dentro del flutter_tester en este entorno (el cuerpo
  // del test nunca avanza), mientras que createSync/writeAsBytesSync
  // funcionan en el acto. Ver preview.sh.
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

AdminService _ownerService({
  required UsersRepository users,
  required AdminsRepository admins,
  required SettingsRepository settings,
}) => AdminService(
  me: ownerRecord(),
  users: users,
  admins: admins,
  settings: settings,
);

void main() {
  // flutter_test en este entorno NO carga las fuentes declaradas en
  // pubspec (ni la fuente por defecto: sin esto, TODO el texto sale
  // como bloques negros). Se carga Nunito a mano con FontLoader antes
  // de cada proceso de preview. Es solo del test: la app real en el
  // teléfono carga las fuentes del pubspec al compilar, sin problema.
  setUpAll(() async {
    final loader = FontLoader('Nunito');
    for (final asset in [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
    ]) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
    // Los iconos Material tampoco los carga flutter_test: se carga la
    // fuente de iconos a mano para que los previews no muestren
    // cuadrados vacíos en lugar de iconos.
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(
      rootBundle.load('assets/MaterialIcons-Regular.otf'),
    );
    await iconLoader.load();
  });

  testWidgets('preview: panel', (tester) async {
    await _savePreview(
      tester,
      'panel.png',
      DashboardScreen(
        users: FakeUsersRepository(seedUsers()),
        reports: FakeReportsRepository(seedReports()),
        me: ownerRecord(),
        onNavigate: (_) {},
      ),
    );
  });

  testWidgets('preview: estadísticas', (tester) async {
    // El mismo Panel con los 12 usuarios de ejemplo: las estadísticas
    // (activos/día, atasco, fallos, versiones) se calculan de esos datos.
    await _savePreview(
      tester,
      'estadisticas.png',
      DashboardScreen(
        users: FakeUsersRepository(seedUsers()),
        reports: FakeReportsRepository(seedReports()),
        me: ownerRecord(),
        onNavigate: (_) {},
      ),
    );
  });

  testWidgets('preview: menú', (tester) async {
    await _savePreview(
      tester,
      'menu.png',
      SizedBox(
        width: 304,
        child: AdminDrawer(
          me: ownerRecord(),
          current: AdminSection.panel,
          onSelect: (_) {},
          onSignOut: () {},
          canSeeUsers: true,
          canManage: true,
        ),
      ),
    );
  });

  testWidgets('preview: tabla de posiciones', (tester) async {
    // La tabla queda bajo el pliegue del Panel: este preview hace scroll
    // hasta ella para verificarla visualmente.
    await _savePreview(
      tester,
      'tabla_posiciones.png',
      DashboardScreen(
        users: FakeUsersRepository(seedUsers()),
        reports: FakeReportsRepository(seedReports()),
        me: ownerRecord(),
        onNavigate: (_) {},
      ),
      onReady: (t) async {
        // Drag manual (no scrollUntilVisible: su drag interno no encuentra
        // el Scrollable bajo el RefreshIndicator en este árbol, aunque
        // exista; el drag directo sobre el ListView sí funciona).
        await t.drag(find.byType(ListView), const Offset(0, -1200));
        await t.pump(const Duration(milliseconds: 300));
        await t.drag(find.byType(ListView), const Offset(0, -1200));
        await t.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('preview: usuarios', (tester) async {
    final users = FakeUsersRepository(seedUsers());
    await _savePreview(
      tester,
      'usuarios.png',
      UsersScreen(
        users: users,
        service: _ownerService(
          users: users,
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
        ),
        me: ownerRecord(),
      ),
    );
  });

  testWidgets('preview: detalle de usuario', (tester) async {
    final users = FakeUsersRepository(seedUsers());
    await _savePreview(
      tester,
      'detalle_usuario.png',
      UserDetailScreen(
        user: seedUsers().first,
        service: _ownerService(
          users: users,
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
        ),
      ),
    );
  });

  testWidgets('preview: administradores', (tester) async {
    final admins = FakeAdminsRepository([
      ownerRecord(),
      readOnlyAdminRecord(),
      const AdminRecord(
        uid: 'pendiente@gmail.com',
        email: 'pendiente@gmail.com',
        role: 'admin',
        permissions: AdminPermissions.readOnly,
        pending: true,
        createdBy: ownerEmail,
      ),
    ]);
    await _savePreview(
      tester,
      'administradores.png',
      AdminsScreen(
        admins: admins,
        service: _ownerService(
          users: FakeUsersRepository(),
          admins: admins,
          settings: FakeSettingsRepository(),
        ),
        me: ownerRecord(),
      ),
    );
  });

  testWidgets('preview: ajustes', (tester) async {
    final settings = FakeSettingsRepository();
    await _savePreview(
      tester,
      'ajustes.png',
      SettingsScreen(
        settings: settings,
        service: _ownerService(
          users: FakeUsersRepository(),
          admins: FakeAdminsRepository(),
          settings: settings,
        ),
        me: ownerRecord(),
      ),
    );
  });

  testWidgets('preview: avisos', (tester) async {
    await _savePreview(
      tester,
      'avisos.png',
      AnnouncementsScreen(
        announcements: FakeAnnouncementsRepository(seedAnnouncements()),
        service: _ownerService(
          users: FakeUsersRepository(),
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
        ),
      ),
    );
  });

  testWidgets('preview: niveles', (tester) async {
    final levels = FakeLevelsRepository(seedLevels());
    await _savePreview(
      tester,
      'niveles.png',
      LevelsScreen(
        levels: levels,
        service: AdminService(
          me: ownerRecord(),
          users: FakeUsersRepository(),
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
          levels: levels,
          reports: FakeReportsRepository(seedReports()),
        ),
        onNavigate: (_) {},
      ),
    );
  });

  testWidgets('preview: editor', (tester) async {
    final levels = FakeLevelsRepository(seedLevels());
    await _savePreview(
      tester,
      'editor.png',
      QuestionEditorScreen(
        level: seedLevels().first,
        question: seedLevels().first.questions[2],
        service: AdminService(
          me: ownerRecord(),
          users: FakeUsersRepository(),
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
          levels: levels,
        ),
      ),
    );
  });

  testWidgets('preview: reportes', (tester) async {
    await _savePreview(
      tester,
      'reportes.png',
      ReportsScreen(
        reports: FakeReportsRepository(seedReports()),
        service: _ownerService(
          users: FakeUsersRepository(),
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
        ),
      ),
    );
  });

  testWidgets('preview: soporte', (tester) async {
    await _savePreview(
      tester,
      'soporte.png',
      SupportScreen(
        support: FakeSupportRepository(seedSupportMessages()),
        service: _ownerService(
          users: FakeUsersRepository(),
          admins: FakeAdminsRepository(),
          settings: FakeSettingsRepository(),
        ),
      ),
    );
  });
}
