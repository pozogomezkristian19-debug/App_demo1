// Pantallas de Quemia Admin — panel de administración profesional.
//
// Concha clásica de admin (CodeCanyon / AdminLTE): drawer lateral con las
// secciones organizadas + AppBar + contenido. Panel principal con KPIs,
// tablas limpias y acciones en línea. Sin degradados, sin brillo, sin
// sombras borrosas; paleta neutra + teal como único acento.
//
// Todas las pantallas reciben sus repositorios por constructor, con los de
// Firestore como valor por defecto, para poder inyectar fakes en tests y
// previews.

import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'design.dart';
import 'models.dart';
import 'push_service.dart';
import 'repositories.dart';
import 'stats.dart';

const tealPrimary = AdminColors.teal;

/// Tema del panel: claro, fondo gris muy claro, tarjetas blancas con
/// borde fino, Nunito empaquetada. Lo usan la app (main.dart) y los
/// tests de preview.
ThemeData quemiaAdminTheme() {
  return ThemeData(
    useMaterial3: true,
    // Nunito empaquetada (assets/fonts/): es la fuente que hace que los
    // previews muestren texto legible en vez de bloques.
    fontFamily: 'Nunito',
    colorScheme: const ColorScheme.light(
      primary: AdminColors.teal,
      onPrimary: Colors.white,
      surface: AdminColors.card,
      onSurface: AdminColors.ink,
    ),
    scaffoldBackgroundColor: AdminColors.pageBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.card,
      foregroundColor: AdminColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AdminColors.ink),
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AdminColors.ink,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AdminColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: AdminColors.line),
      ),
      margin: EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.tealDark,
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.teal, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AdminColors.muted),
      hintStyle: const TextStyle(color: AdminColors.faint),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AdminColors.teal
            : AdminColors.line,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AdminColors.teal
            : AdminColors.faint,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AdminColors.line,
      thickness: 1,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AdminColors.ink,
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AdminColors.teal,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AdminColors.teal,
    ),
  );
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'ahora mismo';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}

/// Engancha un manejador de error en el momento de crear un futuro.
///
/// Sin esto hay una carrera: si el futuro falla ANTES de que el
/// FutureBuilder se suscriba (en el siguiente frame), la zona reporta el
/// error como "no manejado" aunque el FutureBuilder lo mostraría después
/// como estado tranquilo. Con el manejador enganchado desde la creación,
/// el error queda manejado y el FutureBuilder lo sigue recibiendo igual
/// (los futuros admiten varios oyentes). En producción la carrera casi no
/// ocurre (la red tarda más que un frame), pero en tests con fakes que
/// fallan al instante es sistemática.
Future<T> _guarded<T>(Future<T> future) {
  future.then((_) {}, onError: (_) {});
  return future;
}

/// Estado tranquilo cuando no hay conexión (o Firestore falla).
///
/// Regla dura: sin internet NO pasa nada malo — ni diálogo de error, ni
/// banner rojo, ni bloqueo ni cierre. Solo este estado calmado con el botón
/// de reintentar. Se usa en todas las pantallas que cargan de Firestore.
/// Aviso neutro (SnackBar normal, sin rojo) cuando una acción falla por
/// falta de conexión. Nunca un diálogo ni un banner de error.
void showOfflineNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Sin conexión. Inténtalo de nuevo.')),
  );
}

/// Estado vacío: icono en cuadrado tintado, título y subtítulo.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AdminColors.greyTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 34, color: AdminColors.muted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AdminText.title,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AdminText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class CalmOfflineState extends StatelessWidget {
  const CalmOfflineState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AdminColors.greyTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.wifi_off,
                size: 34,
                color: AdminColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Sin conexión', style: AdminText.title),
            const SizedBox(height: 6),
            const Text(
              'No se pudo cargar la información. Revisa tu conexión e '
              'inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: AdminText.caption,
            ),
            const SizedBox(height: 20),
            AdminButton.primary(
              label: 'Reintentar',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta centrada para las pantallas de acceso (login, sin acceso,
/// falta Firebase): marca arriba, título, contenido.
class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.iconTint,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconTint;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AdminCard(
            padding: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, size: 34, color: iconColor),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantallas de auth / errores de configuración
// ---------------------------------------------------------------------------

/// Pantalla cuando Firebase no se pudo inicializar (p. ej. falta
/// google-services.json). No se rompe la app: se explica el problema.
class FirebaseMissingScreen extends StatelessWidget {
  const FirebaseMissingScreen({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quemia Admin')),
      body: _AccessCard(
        icon: Icons.warning_amber_rounded,
        iconTint: AdminColors.amberTint,
        iconColor: AdminColors.amberDark,
        title: 'Falta configurar Firebase',
        children: [
          const Text(
            'Esta app necesita su archivo google-services.json en '
            'android/app/ con el paquete com.melliqui.quemia_admin. '
            'Sin él no puede conectarse a Firestore.',
            textAlign: TextAlign.center,
            style: AdminText.caption,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AdminColors.faint),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de inicio de sesión con Google. Es lo primero que se ve al
/// abrir la app: entrar directo, sin bienvenida ni pasos intermedios.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final GoogleAuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        // Mensaje claro y honesto: la app NO se cuelga ni se cierra, y el
        // botón queda disponible para reintentarlo. El detalle técnico va
        // en letra pequeña debajo, por si hace falta diagnosticar.
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AccessCard(
        icon: Icons.admin_panel_settings,
        iconTint: AdminColors.teal,
        iconColor: Colors.white,
        title: 'Quemia Admin',
        children: [
          const Text(
            'Panel de administración de la app Quemia',
            textAlign: TextAlign.center,
            style: AdminText.caption,
          ),
          const SizedBox(height: 28),
          AdminButton.secondary(
            label: _busy ? 'Iniciando sesión…' : 'Continuar con Google',
            leading: const GoogleGIcon(),
            onPressed: _busy ? null : _signIn,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            const Text(
              'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminColors.redDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AdminColors.faint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pantalla cuando el usuario entró con Google pero NO está en 'admins'.
/// Muestra su uid para que el dueño lo pueda dar de alta en Firestore.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({
    super.key,
    required this.email,
    required this.uid,
    required this.authService,
  });

  final String email;
  final String uid;
  final GoogleAuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quemia Admin')),
      body: _AccessCard(
        icon: Icons.lock_outline,
        iconTint: AdminColors.amberTint,
        iconColor: AdminColors.amberDark,
        title: 'No tienes acceso de administrador',
        children: [
          Text(
            'Entraste como $email, pero esa cuenta no está en la lista de '
            'administradores de Quemia.',
            textAlign: TextAlign.center,
            style: AdminText.caption,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.greyTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              'Tu uid de Firebase es:\n$uid',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AdminColors.muted),
            ),
          ),
          const SizedBox(height: 24),
          AdminButton.secondary(
            label: 'Cerrar sesión',
            icon: Icons.logout,
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawer de navegación (la concha del panel)
// ---------------------------------------------------------------------------

/// Elemento del drawer: icono + etiqueta; activo con fondo tintado teal,
/// texto teal oscuro y barra de 3 pt a la izquierda.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AdminColors.tealDark : AdminColors.body;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AdminColors.tealTint : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? AdminColors.teal : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drawer del panel: marca, secciones organizadas y pie con la cuenta.
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({
    super.key,
    required this.me,
    required this.current,
    required this.onSelect,
    required this.onSignOut,
    required this.canSeeUsers,
    required this.canManage,
  });

  final AdminRecord me;
  final AdminSection current;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onSignOut;
  final bool canSeeUsers;

  /// true si puede gestionar (avisos, editor, reportes, soporte, ajustes,
  /// admins). El dueño siempre lo cumple.
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    void select(AdminSection section) {
      Navigator.of(context).pop();
      onSelect(section);
    }

    return Drawer(
      backgroundColor: AdminColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AdminColors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quemia Admin', style: AdminText.title),
                        Text(
                          'PANEL DE ADMINISTRACIÓN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text('PRINCIPAL', style: AdminText.sectionLabel),
                  ),
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Panel',
                    selected: current == AdminSection.panel,
                    onTap: () => select(AdminSection.panel),
                  ),
                  if (canSeeUsers) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('GESTIÓN', style: AdminText.sectionLabel),
                    ),
                    _DrawerItem(
                      icon: Icons.people_outlined,
                      label: 'Usuarios',
                      selected: current == AdminSection.usuarios,
                      onTap: () => select(AdminSection.usuarios),
                    ),
                  ],
                  if (canManage) ...[
                    if (!canSeeUsers)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('GESTIÓN', style: AdminText.sectionLabel),
                      ),
                    _DrawerItem(
                      icon: Icons.campaign_outlined,
                      label: 'Avisos',
                      selected: current == AdminSection.avisos,
                      onTap: () => select(AdminSection.avisos),
                    ),
                    _DrawerItem(
                      icon: Icons.edit_note_outlined,
                      label: 'Editor de contenido',
                      selected: current == AdminSection.editor,
                      onTap: () => select(AdminSection.editor),
                    ),
                    _DrawerItem(
                      icon: Icons.flag_outlined,
                      label: 'Reportes',
                      selected: current == AdminSection.reportes,
                      onTap: () => select(AdminSection.reportes),
                    ),
                    _DrawerItem(
                      icon: Icons.support_agent_outlined,
                      label: 'Soporte',
                      selected: current == AdminSection.soporte,
                      onTap: () => select(AdminSection.soporte),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('EQUIPO', style: AdminText.sectionLabel),
                    ),
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Administradores',
                      selected: current == AdminSection.admins,
                      onTap: () => select(AdminSection.admins),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('SISTEMA', style: AdminText.sectionLabel),
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Ajustes',
                      selected: current == AdminSection.ajustes,
                      onTap: () => select(AdminSection.ajustes),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const AdminUserAvatar(radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.displayName.isEmpty ? me.email : me.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.bodyBold,
                        ),
                        Text(
                          me.isOwner ? 'Dueño' : 'Administrador',
                          style: AdminText.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AdminColors.muted),
                    tooltip: 'Cerrar sesión',
                    onPressed: onSignOut,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell con drawer
// ---------------------------------------------------------------------------

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.me,
    required this.authService,
    this.users,
    this.admins,
    this.settings,
    this.levels,
    this.announcements,
    this.reports,
    this.support,
  });

  final AdminRecord me;
  final GoogleAuthService authService;
  final UsersRepository? users;
  final AdminsRepository? admins;
  final SettingsRepository? settings;
  final LevelsRepository? levels;
  final AnnouncementsRepository? announcements;
  final ReportsRepository? reports;
  final SupportRepository? support;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AdminSection _section = AdminSection.panel;

  @override
  void initState() {
    super.initState();
    // Toques en pushes FCM: navegar a la sección que corresponde.
    PushService.pendingSection.addListener(_onPushSection);
    // Si la app se abrió tocando un push, la sección ya está pendiente.
    _onPushSection();
    // El admin ya está verificado aquí: guardar su token FCM para que las
    // Cloud Functions le manden los pushes (nunca antes, ver push_service.dart).
    unawaited(PushService.shared.registerAdmin(widget.me.uid));
  }

  void _onPushSection() {
    final section = PushService.pendingSection.value;
    if (section == null) return;
    PushService.pendingSection.value = null;
    setState(() => _section = section);
  }

  @override
  void dispose() {
    PushService.pendingSection.removeListener(_onPushSection);
    PushService.shared.unregisterAdmin();
    super.dispose();
  }

  late final UsersRepository _users =
      widget.users ?? FirestoreUsersRepository();
  late final AdminsRepository _admins =
      widget.admins ?? FirestoreAdminsRepository();
  late final SettingsRepository _settings =
      widget.settings ?? FirestoreSettingsRepository();
  late final LevelsRepository _levels =
      widget.levels ?? FirestoreLevelsRepository();
  late final AnnouncementsRepository _announcements =
      widget.announcements ?? FirestoreAnnouncementsRepository();
  late final ReportsRepository _reports =
      widget.reports ?? FirestoreReportsRepository();
  late final SupportRepository _support =
      widget.support ?? FirestoreSupportRepository();

  late final AdminService _service = AdminService(
    me: widget.me,
    users: _users,
    admins: _admins,
    settings: _settings,
    levels: _levels,
    announcements: _announcements,
    reports: _reports,
    support: _support,
  );

  String get _title => switch (_section) {
    AdminSection.panel => 'Panel',
    AdminSection.usuarios => 'Usuarios',
    AdminSection.avisos => 'Avisos',
    AdminSection.editor => 'Editor de contenido',
    AdminSection.reportes => 'Reportes',
    AdminSection.soporte => 'Soporte',
    AdminSection.admins => 'Administradores',
    AdminSection.ajustes => 'Ajustes remotos',
  };

  @override
  Widget build(BuildContext context) {
    final canSeeUsers = widget.me.canViewUsers();
    final canManage = widget.me.canManageAdmins();

    Widget body;
    switch (_section) {
      case AdminSection.panel:
        body = DashboardScreen(
          users: _users,
          me: widget.me,
          reports: _reports,
          support: _support,
          onNavigate: (s) => setState(() => _section = s),
        );
      case AdminSection.usuarios:
        body = UsersScreen(users: _users, service: _service, me: widget.me);
      case AdminSection.avisos:
        body = AnnouncementsScreen(
          announcements: _announcements,
          service: _service,
        );
      case AdminSection.editor:
        body = LevelsScreen(
          levels: _levels,
          service: _service,
          onNavigate: (s) => setState(() => _section = s),
        );
      case AdminSection.reportes:
        body = ReportsScreen(reports: _reports, service: _service);
      case AdminSection.soporte:
        body = SupportScreen(support: _support, service: _service);
      case AdminSection.admins:
        body = AdminsScreen(admins: _admins, service: _service, me: widget.me);
      case AdminSection.ajustes:
        body = SettingsScreen(
          settings: _settings,
          service: _service,
          me: widget.me,
        );
    }
    // Si el índice quedó fuera de rango por los permisos, volver al Panel.
    if (_section == AdminSection.usuarios && !canSeeUsers) {
      body = DashboardScreen(
        users: _users,
        me: widget.me,
        reports: _reports,
        support: _support,
        onNavigate: (s) => setState(() => _section = s),
      );
    }
    if (_section != AdminSection.panel &&
        _section != AdminSection.usuarios &&
        !canManage) {
      body = DashboardScreen(
        users: _users,
        me: widget.me,
        reports: _reports,
        support: _support,
        onNavigate: (s) => setState(() => _section = s),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      drawer: AdminDrawer(
        me: widget.me,
        current: _section,
        onSelect: (s) => setState(() => _section = s),
        onSignOut: () => widget.authService.signOut(),
        canSeeUsers: canSeeUsers,
        canManage: canManage,
      ),
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
// (a) Panel
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.users,
    required this.me,
    this.reports,
    this.support,
    this.onNavigate,
  });

  final UsersRepository users;
  final AdminRecord me;

  /// Reportes para las estadísticas de preguntas con más fallos. Si es
  /// null, esa tarjeta muestra el estado vacío.
  final ReportsRepository? reports;

  /// Mensajes de soporte (para el contador de abiertos de la tarjeta).
  final SupportRepository? support;

  /// Navegación a una sección del drawer. Si es null, las tarjetas de
  /// acción no se muestran (p. ej. en previews sin navegación).
  final ValueChanged<AdminSection>? onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<(List<AppUser>, List<QuestionReport>, List<SupportMessage>)>
  _future;

  @override
  void initState() {
    super.initState();
    _future = _guarded(_load());
  }

  Future<(List<AppUser>, List<QuestionReport>, List<SupportMessage>)>
  _load() async {
    final users = await widget.users.listUsers();
    final reports = widget.reports == null
        ? <QuestionReport>[]
        : await widget.reports!.listReports();
    final support = widget.support == null
        ? <SupportMessage>[]
        : await widget.support!.listMessages();
    return (users, reports, support);
  }

  void _reload() {
    setState(() {
      _future = _guarded(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<AppUser>, List<QuestionReport>, List<SupportMessage>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return CalmOfflineState(onRetry: _reload);
        }
        final users = snap.data?.$1 ?? [];
        final reports = snap.data?.$2 ?? [];
        final support = snap.data?.$3 ?? [];
        final stats = computeStats(users: users, reports: reports);
        final recent = users.take(5).toList();
        // Tabla de posiciones en vivo (modelo Elite Quiz: el dashboard
        // muestra la clasificación actual, no solo estadísticas).
        final topUsers = users.toList()
          ..sort((a, b) => b.points.compareTo(a.points));
        final top5 = topUsers.take(5).toList();
        final newThisWeek = users
            .where((u) => DateTime.now().difference(u.joinedAt).inDays < 7)
            .length;
        final openReports = reports.where((r) => !r.isFixed).length;
        final openSupport = support.where((m) => !m.isAnswered).length;
        final canManage = widget.me.canManageAdmins();
        final nav = widget.onNavigate;

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await _future;
            } catch (_) {
              // El estado tranquilo ya muestra el fallo; el refresh no debe
              // lanzar.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${widget.me.displayName.isEmpty ? widget.me.email : widget.me.displayName}',
                          style: AdminText.screenTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.me.isOwner ? 'Dueño' : 'Administrador',
                          style: AdminText.caption,
                        ),
                      ],
                    ),
                  ),
                  if (widget.me.isOwner)
                    const AdminStatusChip.owner(label: 'Dueño')
                  else
                    const AdminStatusChip.done(label: 'Admin'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      label: 'Usuarios unidos',
                      value: '${stats.totalUsers}',
                      icon: Icons.people_outlined,
                      tint: AdminColors.tealTint,
                      iconColor: AdminColors.tealDark,
                      caption: '+$newThisWeek esta semana',
                      captionColor: AdminColors.tealDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdminKpiCard(
                      label: 'Activos hoy',
                      value: '${stats.activeToday}',
                      icon: Icons.today_outlined,
                      tint: AdminColors.greenTint,
                      iconColor: AdminColors.greenDark,
                      caption: 'de ${stats.totalUsers} usuarios',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AdminKpiCard(
                      label: 'Nivel medio',
                      value: stats.avgLevel.toStringAsFixed(1),
                      icon: Icons.trending_up,
                      tint: AdminColors.blueTint,
                      iconColor: AdminColors.blueDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdminKpiCard(
                      label: 'Reportes abiertos',
                      value: '$openReports',
                      icon: Icons.flag_outlined,
                      tint: AdminColors.amberTint,
                      iconColor: AdminColors.amberDark,
                      caption: '$openReports pendientes',
                      captionColor: AdminColors.amberDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const AdminSectionHeader('ESTADÍSTICAS'),
              _StatsCard(stats: stats),
              if (canManage && nav != null) ...[
                const SizedBox(height: 24),
                const AdminSectionHeader('ACCIONES RÁPIDAS'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _ActionTile(
                      icon: Icons.campaign_outlined,
                      title: 'Avisos',
                      subtitle: 'Mensaje a todos',
                      tint: AdminColors.tealTint,
                      iconColor: AdminColors.tealDark,
                      onTap: () => nav(AdminSection.avisos),
                    ),
                    _ActionTile(
                      icon: Icons.edit_note_outlined,
                      title: 'Editor',
                      subtitle: 'Preguntas y niveles',
                      tint: AdminColors.blueTint,
                      iconColor: AdminColors.blueDark,
                      onTap: () => nav(AdminSection.editor),
                    ),
                    _ActionTile(
                      icon: Icons.flag_outlined,
                      title: 'Reportes',
                      subtitle: '$openReports abiertos',
                      tint: AdminColors.amberTint,
                      iconColor: AdminColors.amberDark,
                      onTap: () => nav(AdminSection.reportes),
                    ),
                    _ActionTile(
                      icon: Icons.support_agent_outlined,
                      title: 'Soporte',
                      subtitle: '$openSupport sin responder',
                      tint: AdminColors.greenTint,
                      iconColor: AdminColors.greenDark,
                      onTap: () => nav(AdminSection.soporte),
                    ),
                    _ActionTile(
                      icon: Icons.settings_outlined,
                      title: 'Ajustes',
                      subtitle: 'Puntos y vidas',
                      tint: AdminColors.greyTint,
                      iconColor: AdminColors.muted,
                      onTap: () => nav(AdminSection.ajustes),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const AdminSectionHeader('UNIDOS RECIENTEMENTE'),
              if (recent.isEmpty)
                const AdminCard(
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: 'Sin usuarios todavía',
                    subtitle:
                        'Cuando alguien se una a Quemia, aparecerá aquí.',
                  ),
                )
              else
                AdminCard(
                  padding: 0,
                  child: Column(
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0) const AdminRowDivider(),
                        _RecentUserRow(user: recent[i]),
                      ],
                    ],
                  ),
                ),
              // Tabla de posiciones en vivo (modelo Elite Quiz): los 5 con
              // más puntos, con su puesto, avatar y puntos. Solo lectura.
              if (users.isNotEmpty) ...[
                const SizedBox(height: 24),
                const AdminSectionHeader('TABLA DE POSICIONES'),
                AdminCard(
                  padding: 0,
                  child: Column(
                    children: [
                      for (var i = 0; i < top5.length; i++) ...[
                        if (i > 0) const AdminRowDivider(),
                        _LeaderboardRow(rank: i + 1, user: top5[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Fila de la tabla de posiciones: puesto en círculo tintado + avatar +
/// nombre y progreso + puntos a la derecha, en negrita.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.user});

  final int rank;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (rank) {
      1 => (AdminColors.amberTint, AdminColors.amberDark),
      2 => (AdminColors.greyTint, AdminColors.muted),
      3 => (AdminColors.tealTint, AdminColors.tealDark),
      _ => (AdminColors.greyTint, AdminColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AdminUserAvatar(radius: 20, banned: user.banned),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: AdminText.bodyBold),
                const SizedBox(height: 2),
                Text(
                  'Niveles: ${user.totalLevelsPassed} · Racha ${user.streak}',
                  style: AdminText.caption,
                ),
              ],
            ),
          ),
          if (user.banned)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: AdminStatusChip.banned(label: 'Baneado'),
            ),
          Text(
            '${user.points} pts',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AdminColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentUserRow extends StatelessWidget {
  const _RecentUserRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AdminUserAvatar(radius: 20, banned: user.banned),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: AdminText.bodyBold),
                const SizedBox(height: 2),
                Text(
                  'Se unió el ${formatDate(user.joinedAt)} · ${user.points} puntos',
                  style: AdminText.caption,
                ),
              ],
            ),
          ),
          if (user.banned)
            const AdminStatusChip.banned(label: 'Baneado'),
        ],
      ),
    );
  }
}

/// Baldosa de acción rápida del Panel: icono en cuadrado tintado +
/// título + subtítulo, en tarjeta blanca.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: 12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AdminText.bodyBold),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de estadísticas: activos por día (últimos 7 días), nivel donde
/// más se atascan, preguntas con más fallos y versiones de la app.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final AdminStats stats;

  static const _weekdayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxDay = stats.activePerDay.isEmpty
        ? 1
        : stats.activePerDay.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final now = DateTime.now();
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activos por día', style: AdminText.bodyBold),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final day = now.subtract(Duration(days: 6 - i));
              final count = stats.activePerDay[6 - i];
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 8 + 44 * (count / maxDay),
                      width: 18,
                      decoration: BoxDecoration(
                        color: i == 6
                            ? AdminColors.teal
                            : AdminColors.teal.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _weekdayLetters[day.weekday - 1],
                      style: AdminText.caption,
                    ),
                  ],
                ),
              );
            }),
          ),
          const Divider(height: 28),
          _StatRow(
            icon: Icons.hourglass_bottom,
            tint: AdminColors.amberTint,
            iconColor: AdminColors.amberDark,
            label: 'Nivel donde más se atascan',
            value: stats.stuckLevelLabel.isEmpty
                ? 'Sin datos'
                : '${stats.stuckLevelLabel} (${stats.stuckCount})',
          ),
          const Divider(height: 28),
          _StatListHeader(
            icon: Icons.quiz_outlined,
            tint: AdminColors.blueTint,
            iconColor: AdminColors.blueDark,
            label: 'Preguntas con más fallos',
          ),
          if (stats.mostFailed.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sin reportes abiertos. ¡Bien!',
                style: AdminText.caption,
              ),
            )
          else
            ...stats.mostFailed.take(3).map(
              (f) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.questionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.body,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AdminStatusChip.done(label: '${f.count} reportes'),
                  ],
                ),
              ),
            ),
          const Divider(height: 28),
          _StatListHeader(
            icon: Icons.phone_android_outlined,
            tint: AdminColors.greenTint,
            iconColor: AdminColors.greenDark,
            label: 'Versiones de la app',
          ),
          if (stats.versionCounts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Sin datos', style: AdminText.caption),
            )
          else
            ...stats.versionCounts.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text('v${e.key}', style: AdminText.bodyBold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: stats.totalUsers == 0
                              ? 0
                              : e.value / stats.totalUsers,
                          backgroundColor: AdminColors.greyTint,
                          color: AdminColors.teal,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${e.value}', style: AdminText.bodyBold),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AdminText.caption),
              const SizedBox(height: 2),
              Text(value, style: AdminText.bodyBold),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatListHeader extends StatelessWidget {
  const _StatListHeader({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AdminText.bodyBold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// (b) Usuarios
// ---------------------------------------------------------------------------

/// Píldora de filtro de la tabla de usuarios: seleccionada = fondo teal
/// tintado + texto teal oscuro; sin seleccionar = blanca con borde gris.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AdminColors.tealTint : AdminColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AdminColors.teal : AdminColors.line,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? AdminColors.tealDark : AdminColors.muted,
          ),
        ),
      ),
    );
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.users,
    required this.service,
    required this.me,
  });

  final UsersRepository users;
  final AdminService service;
  final AdminRecord me;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

enum _UserFilter { todos, activos, baneados }

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<AppUser>> _future;
  String _query = '';
  _UserFilter _filter = _UserFilter.todos;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.users.listUsers());
  }

  void _reload() {
    setState(() {
      _future = _guarded(widget.users.listUsers());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: AdminSearchField(
            hintText: 'Buscar por nombre…',
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        // Filtros de moderación (modelo Elite Quiz: la tabla de usuarios
        // se filtra por estado, no solo por búsqueda).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              _FilterPill(
                label: 'Todos',
                selected: _filter == _UserFilter.todos,
                onTap: () => setState(() => _filter = _UserFilter.todos),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Activos hoy',
                selected: _filter == _UserFilter.activos,
                onTap: () => setState(() => _filter = _UserFilter.activos),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Baneados',
                selected: _filter == _UserFilter.baneados,
                onTap: () =>
                    setState(() => _filter = _UserFilter.baneados),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppUser>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return CalmOfflineState(onRetry: _reload);
              }
              final all = snap.data ?? [];
              final byFilter = switch (_filter) {
                _UserFilter.todos => all,
                _UserFilter.activos =>
                  all.where((u) => u.activeToday).toList(),
                _UserFilter.baneados => all.where((u) => u.banned).toList(),
              };
              final filtered = _query.isEmpty
                  ? byFilter
                  : byFilter
                        .where((u) => u.username.toLowerCase().contains(_query))
                        .toList();
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: all.isEmpty
                      ? 'Sin usuarios todavía'
                      : 'Sin resultados',
                  subtitle: all.isEmpty
                      ? 'Cuando alguien se una a Quemia, aparecerá aquí.'
                      : 'Ningún usuario coincide con la búsqueda o el filtro.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final u = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdminCard(
                        padding: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => UserDetailScreen(
                                  user: u,
                                  service: widget.service,
                                ),
                              ),
                            );
                            _reload();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                AdminUserAvatar(radius: 22, banned: u.banned),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.username,
                                        style: AdminText.bodyBold,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Unido: ${formatDate(u.joinedAt)} · Últ. vez: ${timeAgo(u.lastActive)}\n'
                                        'Niveles: ${u.totalLevelsPassed} (Bach ${u.levelsBachPassed} · Uni ${u.levelsUniPassed}) · '
                                        '${u.points} pts · Racha ${u.streak} · v${u.appVersion}',
                                        style: AdminText.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (u.banned)
                                  const AdminStatusChip.banned(
                                    label: 'Baneado',
                                  )
                                else
                                  const AdminStatusChip.success(
                                    label: 'Activo',
                                  ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AdminColors.faint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// (c) Detalle de usuario + banear / quitar baneo
// ---------------------------------------------------------------------------

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.user,
    required this.service,
  });

  final AppUser user;
  final AdminService service;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late AppUser _user = widget.user;
  bool _busy = false;

  Future<void> _toggleBan() async {
    if (_user.banned) {
      setState(() => _busy = true);
      try {
        await widget.service.unbanUser(_user);
        if (mounted) {
          setState(() {
            _user = _user.copyWith(banned: false, bannedReason: '');
            _busy = false;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Baneo retirado.')));
        }
      } on PermissionDenied catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } on Exception {
        if (mounted) {
          setState(() => _busy = false);
          showOfflineNotice(context);
        }
      }
      return;
    }
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Banear usuario'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motivo del baneo',
            hintText: 'Ej.: trampas en el examen',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.red,
            ),
            child: const Text('Banear'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await widget.service.banUser(_user, reason);
      if (mounted) {
        setState(() {
          _user = _user.copyWith(
            banned: true,
            bannedReason: reason,
            bannedAt: DateTime.now(),
          );
          _busy = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Usuario baneado.')));
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) {
        setState(() => _busy = false);
        showOfflineNotice(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canBan = widget.service.me.canBanUsers();
    return Scaffold(
      appBar: AppBar(title: Text(_user.username)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminCard(
            child: Column(
              children: [
                AdminUserAvatar(radius: 36, banned: _user.banned),
                const SizedBox(height: 12),
                Text(_user.username, style: AdminText.screenTitle),
                const SizedBox(height: 8),
                if (_user.banned)
                  const AdminStatusChip.banned(label: 'Baneado')
                else
                  const AdminStatusChip.success(label: 'Activo'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminCard(
            padding: 16,
            child: Column(
              children: [
                AdminDetailRow(
                  label: 'Se unió',
                  value: formatDateTime(_user.joinedAt),
                ),
                const AdminRowDivider(),
                AdminDetailRow(
                  label: 'Última vez',
                  value: formatDateTime(_user.lastActive),
                ),
                const AdminRowDivider(),
                AdminDetailRow(
                  label: 'Pista',
                  value: _user.track == 'uni'
                      ? 'Universidad'
                      : 'Bachillerato',
                ),
                const AdminRowDivider(),
                AdminDetailRow(
                  label: 'Niveles Bachillerato',
                  value: '${_user.levelsBachPassed}',
                ),
                const AdminRowDivider(),
                AdminDetailRow(
                  label: 'Niveles Universidad',
                  value: '${_user.levelsUniPassed}',
                ),
                const AdminRowDivider(),
                AdminDetailRow(
                  label: 'Niveles totales',
                  value: '${_user.totalLevelsPassed}',
                ),
                const AdminRowDivider(),
                AdminDetailRow(label: 'Puntos', value: '${_user.points}'),
                const AdminRowDivider(),
                AdminDetailRow(label: 'Racha', value: '${_user.streak} días'),
                const AdminRowDivider(),
                AdminDetailRow(
                  label: 'Versión de la app',
                  value: _user.appVersion,
                ),
                if (_user.banned) ...[
                  const AdminRowDivider(),
                  AdminDetailRow(
                    label: 'Motivo del baneo',
                    value: _user.bannedReason,
                  ),
                  if (_user.bannedAt != null) ...[
                    const AdminRowDivider(),
                    AdminDetailRow(
                      label: 'Baneado el',
                      value: formatDateTime(_user.bannedAt!),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_user.banned)
            AdminButton.primary(
              label: _busy ? 'Quitando baneo…' : 'Quitar baneo',
              icon: Icons.lock_open,
              onPressed: (!canBan || _busy) ? null : _toggleBan,
            )
          else
            AdminButton.destructive(
              label: _busy ? 'Baneando…' : 'Banear usuario',
              icon: Icons.block,
              onPressed: (!canBan || _busy) ? null : _toggleBan,
            ),
          if (!canBan)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'No tienes permiso para banear usuarios.',
                textAlign: TextAlign.center,
                style: AdminText.caption,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// (d) Administradores
// ---------------------------------------------------------------------------

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({
    super.key,
    required this.admins,
    required this.service,
    required this.me,
  });

  final AdminsRepository admins;
  final AdminService service;
  final AdminRecord me;

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  late Future<List<AdminRecord>> _future;
  final _emailController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.admins.listAdmins());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _guarded(widget.admins.listAdmins());
    });
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un correo de Google válido.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.inviteAdmin(email: email);
      if (mounted) {
        _emailController.clear();
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invitación creada para $email. Entrará con su cuenta de Google.',
            ),
          ),
        );
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) showOfflineNotice(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _permSwitch(
    AdminRecord admin,
    String label,
    bool value,
    AdminPermissions Function(AdminPermissions, bool) apply,
  ) {
    final canManage = widget.service.me.canManageAdmins();
    // El dueño nunca se toca desde la UI; el resto lo valida AdminService
    // (incluido no concederse permisos a uno mismo).
    final locked = admin.isOwner;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AdminText.body),
      value: value,
      onChanged: (!canManage || locked)
          ? null
          : (next) async {
              try {
                await widget.service.setAdminPermissions(
                  admin,
                  apply(admin.permissions, next),
                );
                _reload();
              } on PermissionDenied catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              } on Exception {
                if (mounted) showOfflineNotice(context);
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.service.me.canManageAdmins();
    return FutureBuilder<List<AdminRecord>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return CalmOfflineState(onRetry: _reload);
        }
        final admins = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AdminSectionHeader('AGREGAR ADMINISTRADOR'),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo de Google',
                      hintText: 'correo@gmail.com',
                    ),
                    enabled: canManage && !_busy,
                  ),
                  const SizedBox(height: 12),
                  AdminButton.primary(
                    label: 'Agregar administrador',
                    icon: Icons.person_add_outlined,
                    onPressed: (canManage && !_busy) ? _invite : null,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'El nuevo admin entra con su cuenta de Google y empieza '
                    'solo con permisos de lectura.',
                    style: AdminText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const AdminSectionHeader('ADMINISTRADORES'),
            ...admins.map(
              (admin) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AdminCard(
                  padding: 0,
                  // Material transparente: el encabezado de ExpansionTile
                  // es un ListTile y dentro de la tarjeta (DecoratedBox)
                  // Flutter protesta en debug. Igual que en Ajustes.
                  child: Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    leading: const AdminUserAvatar(radius: 20),
                    title: Text(
                      admin.displayName.isEmpty
                          ? admin.email
                          : admin.displayName,
                      style: AdminText.bodyBold,
                    ),
                    subtitle: Text(
                      '${admin.email}${admin.pending ? ' · invitación pendiente' : ''}',
                      style: AdminText.caption,
                    ),
                    trailing: admin.isOwner
                        ? const AdminStatusChip.owner(label: 'Dueño')
                        : admin.pending
                            ? const AdminStatusChip.pending(
                                label: 'Pendiente',
                              )
                            : const AdminStatusChip.done(label: 'Admin'),
                    children: [
                      _permSwitch(
                        admin,
                        'Ver usuarios',
                        admin.permissions.viewUsers,
                        (p, v) => p.copyWith(viewUsers: v),
                      ),
                      _permSwitch(
                        admin,
                        'Ver progreso',
                        admin.permissions.viewProgress,
                        (p, v) => p.copyWith(viewProgress: v),
                      ),
                      _permSwitch(
                        admin,
                        'Banear usuarios',
                        admin.permissions.banUsers,
                        (p, v) => p.copyWith(banUsers: v),
                      ),
                      _permSwitch(
                        admin,
                        'Gestionar administradores',
                        admin.permissions.manageAdmins,
                        (p, v) => p.copyWith(manageAdmins: v),
                      ),
                      if (canManage &&
                          !admin.isOwner &&
                          admin.uid != widget.me.uid)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Eliminar administrador'),
                                  content: Text(
                                    '¿Quitar a ${admin.email} como administrador?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AdminColors.red,
                                      ),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                try {
                                  await widget.service.removeAdmin(admin);
                                  _reload();
                                } on PermissionDenied catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                } on Exception {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sin conexión. Inténtalo de nuevo.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: AdminColors.redDark,
                            ),
                            label: const Text(
                              'Eliminar administrador',
                              style: TextStyle(color: AdminColors.redDark),
                            ),
                          ),
                        ),
                      if (admin.isOwner)
                        const Text(
                          'El dueño no se puede eliminar ni se le pueden quitar permisos.',
                          style: AdminText.caption,
                        ),
                    ],
                  ),
                    ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// (e) Ajustes remotos (settings/app)
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.service,
    required this.me,
  });

  final SettingsRepository settings;
  final AdminService service;
  final AdminRecord me;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<RemoteSettings> _future;
  RemoteSettings? _editing;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.settings.load());
  }

  Widget _intField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        key: ValueKey(label),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Future<void> _save() async {
    final next = _editing;
    if (next == null) return;
    final error = RemoteSettings.validate(next);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    try {
      await widget.service.saveSettings(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ajustes guardados. La app Quemia los leerá al abrir.',
            ),
          ),
        );
        setState(() {
          _future = _guarded(widget.settings.load());
          _editing = null;
        });
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) showOfflineNotice(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.service.me.canManageAdmins();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes remotos')),
      body: FutureBuilder<RemoteSettings>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return CalmOfflineState(
              onRetry: () {
                setState(() {
                  _future = _guarded(widget.settings.load());
                  _editing = null;
                });
              },
            );
          }
          final current = _editing ?? snap.data ?? const RemoteSettings();
          // SingleChildScrollView + Column (no ListView): todos los campos
          // existen en el árbol aunque estén bajo el pliegue, y el
          // scroll hasta ellos funciona buscando por texto.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'Estos valores los lee la app Quemia al abrir (documento settings/app).',
                style: AdminText.caption,
              ),
              const SizedBox(height: 20),
              const AdminSectionHeader('APROBADO DE NIVEL'),
              AdminCard(
                child: _intField(
                  label: 'Respuestas correctas para aprobar (1-5)',
                  value: current.passThreshold,
                  enabled: canEdit,
                  onChanged: (v) => setState(
                    () => _editing = current.copyWith(passThreshold: v),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const AdminSectionHeader('PUNTOS POR DIFICULTAD'),
              AdminCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _intField(
                            label: 'Fácil: gana',
                            value: current.pointsEasyGain,
                            enabled: canEdit,
                            onChanged: (v) => setState(
                              () => _editing =
                                  current.copyWith(pointsEasyGain: v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _intField(
                            label: 'Fácil: pierde',
                            value: current.pointsEasyLoss,
                            enabled: canEdit,
                            onChanged: (v) => setState(
                              () => _editing =
                                  current.copyWith(pointsEasyLoss: v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _intField(
                            label: 'Media: gana',
                            value: current.pointsMediumGain,
                            enabled: canEdit,
                            onChanged: (v) => setState(
                              () => _editing =
                                  current.copyWith(pointsMediumGain: v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _intField(
                            label: 'Media: pierde',
                            value: current.pointsMediumLoss,
                            enabled: canEdit,
                            onChanged: (v) => setState(
                              () => _editing =
                                  current.copyWith(pointsMediumLoss: v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _intField(
                            label: 'Difícil: gana',
                            value: current.pointsHardGain,
                            enabled: canEdit,
                            onChanged: (v) => setState(
                              () => _editing =
                                  current.copyWith(pointsHardGain: v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _intField(
                            label: 'Difícil: pierde',
                            value: current.pointsHardLoss,
                            enabled: canEdit,
                            onChanged: (v) => setState(
                              () => _editing =
                                  current.copyWith(pointsHardLoss: v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const AdminSectionHeader('VIDAS'),
              AdminCard(
                child: _intField(
                  label: 'Vidas máximas (1-10)',
                  value: current.maxLives,
                  enabled: canEdit,
                  onChanged: (v) =>
                      setState(() => _editing = current.copyWith(maxLives: v)),
                ),
              ),
              const SizedBox(height: 20),
              const AdminSectionHeader('SOPORTE'),
              AdminCard(
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('Número de soporte (WhatsApp)'),
                      initialValue: current.supportNumber,
                      keyboardType: TextInputType.phone,
                      enabled: canEdit,
                      decoration: const InputDecoration(
                        labelText: 'Número de soporte (WhatsApp)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (text) => setState(
                        () => _editing = current.copyWith(supportNumber: text),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Material transparente: SwitchListTile es un ListTile
                    // y dentro de la tarjeta (DecoratedBox) Flutter
                    // protesta en debug porque su fondo/splash quedarían
                    // ocultos. El Material propio lo resuelve.
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Mostrar WhatsApp en Soporte',
                          style: AdminText.body,
                        ),
                        subtitle: const Text(
                          'Si está apagado, la ventanita de Soporte de la app no muestra el botón de WhatsApp.',
                          style: AdminText.caption,
                        ),
                        value: current.showWhatsApp,
                        onChanged: canEdit
                            ? (v) => setState(
                                () => _editing =
                                    current.copyWith(showWhatsApp: v),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AdminButton.primary(
                label: 'Guardar ajustes',
                icon: Icons.save_outlined,
                onPressed: canEdit ? _save : null,
              ),
              if (!canEdit)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Solo el dueño o un admin con permiso de gestionar administradores puede cambiar estos ajustes.',
                    textAlign: TextAlign.center,
                    style: AdminText.caption,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avisos (colección 'announcements') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Pantalla para mandar un mensaje/anuncio a todos los usuarios.
/// La app principal lee la colección 'announcements' y muestra los activos
/// en su bandeja de notificaciones.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    required this.announcements,
    required this.service,
  });

  final AnnouncementsRepository announcements;
  final AdminService service;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late Future<List<Announcement>> _future;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.announcements.listAnnouncements());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _guarded(widget.announcements.listAnnouncements());
    });
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un título y un mensaje para el aviso.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.publishAnnouncement(title: title, body: body);
      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso publicado para todos.')),
        );
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Aviso no válido.')),
        );
      }
    } on Exception {
      if (mounted) showOfflineNotice(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: FutureBuilder<List<Announcement>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return CalmOfflineState(onRetry: _reload);
          }
          final items = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AdminSectionHeader('NUEVO AVISO'),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ej.: ¡Nuevo torneo!',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        hintText: 'Lo que verán todos los usuarios…',
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminButton.primary(
                      label: _busy ? 'Publicando…' : 'Publicar aviso',
                      icon: Icons.send_outlined,
                      onPressed: _busy ? null : _publish,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const AdminSectionHeader('AVISOS PUBLICADOS'),
              if (items.isEmpty)
                const AdminCard(
                  child: EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Sin avisos todavía',
                    subtitle:
                        'Publica el primero arriba: lo verán todos los usuarios en su bandeja.',
                  ),
                )
              else
                ...items.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: a.active
                                  ? AdminColors.tealTint
                                  : AdminColors.greyTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.campaign_outlined,
                              color: a.active
                                  ? AdminColors.tealDark
                                  : AdminColors.muted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.title, style: AdminText.bodyBold),
                                const SizedBox(height: 2),
                                Text(a.body, style: AdminText.body),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatDate(a.createdAt)} · ${a.createdBy}',
                                  style: AdminText.caption,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Switch(
                                value: a.active,
                                onChanged: (next) async {
                                  try {
                                    await widget.service.setAnnouncementActive(
                                      a.id,
                                      next,
                                    );
                                    _reload();
                                  } on PermissionDenied catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.message)),
                                      );
                                    }
                                  } on Exception {
                                    if (context.mounted) {
                                      showOfflineNotice(context);
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AdminColors.redDark,
                                ),
                                tooltip: 'Eliminar aviso',
                                onPressed: () async {
                                  try {
                                    await widget.service.deleteAnnouncement(
                                      a.id,
                                    );
                                    _reload();
                                  } on PermissionDenied catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.message)),
                                      );
                                    }
                                  } on Exception {
                                    if (context.mounted) {
                                      showOfflineNotice(context);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor de contenido (colección 'levels') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Lista de niveles del banco remoto, agrupada por categoría (pista:
/// Bachillerato / Universidad), como la gestión de preguntas de Elite Quiz.
/// Encima, la cola de preguntas reportadas por revisar. Tocar un nivel
/// abre sus preguntas.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({
    super.key,
    required this.levels,
    required this.service,
    this.onNavigate,
  });

  final LevelsRepository levels;
  final AdminService service;

  /// Para abrir Reportes desde la cola. Si es null, la cola no se muestra.
  final ValueChanged<AdminSection>? onNavigate;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  late Future<List<LevelContent>> _future;
  late Future<List<QuestionReport>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.levels.listLevels());
    _reportsFuture = _guarded(widget.service.reports.listReports());
  }

  void _reload() {
    setState(() {
      _future = _guarded(widget.levels.listLevels());
      _reportsFuture = _guarded(widget.service.reports.listReports());
    });
  }

  Widget _levelCard(LevelContent level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdminCard(
        padding: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LevelQuestionsScreen(
                  level: level,
                  service: widget.service,
                ),
              ),
            );
            _reload();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AdminColors.tealTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${level.level}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.tealDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${level.topicTitle} · Nivel ${level.level}',
                        style: AdminText.bodyBold,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${level.title}\n${level.questions.length} preguntas',
                        style: AdminText.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AdminColors.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor de contenido')),
      body: Column(
        children: [
          // Cola de preguntas reportadas por revisar (modelo Elite Quiz:
          // la moderación vive junto a la gestión de preguntas). Solo se
          // muestra si hay reportes abiertos y se puede navegar a ellos.
          if (widget.onNavigate != null)
            FutureBuilder<List<QuestionReport>>(
              future: _reportsFuture,
              builder: (context, snap) {
                final open =
                    (snap.data ?? []).where((r) => !r.isFixed).length;
                if (open == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AdminColors.amberTint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AdminColors.line,
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          widget.onNavigate!(AdminSection.reportes),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              color: AdminColors.amberDark,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$open ${open == 1 ? 'pregunta reportada' : 'preguntas reportadas'} por revisar',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.amberDark,
                                ),
                              ),
                            ),
                            const Text(
                              'Revisar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AdminColors.amberDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: AdminColors.amberDark,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          Expanded(
            child: FutureBuilder<List<LevelContent>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return CalmOfflineState(onRetry: _reload);
                }
                final levels = snap.data ?? [];
                if (levels.isEmpty) {
                  return const EmptyState(
                    icon: Icons.edit_note,
                    title: 'Sin niveles remotos todavía',
                    subtitle:
                        'Cuando la app principal publique su contenido en la colección levels, aparecerá aquí para editarlo.',
                  );
                }
                final bach =
                    levels.where((l) => l.track != 'uni').toList();
                final uni = levels.where((l) => l.track == 'uni').toList();
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (bach.isNotEmpty) ...[
                        const AdminSectionHeader('BACHILLERATO'),
                        ...bach.map(_levelCard),
                        const SizedBox(height: 16),
                      ],
                      if (uni.isNotEmpty) ...[
                        const AdminSectionHeader('UNIVERSIDAD'),
                        ...uni.map(_levelCard),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Preguntas de un nivel: tocar una abre el editor; el botón añade una nueva.
class LevelQuestionsScreen extends StatefulWidget {
  const LevelQuestionsScreen({
    super.key,
    required this.level,
    required this.service,
  });

  final LevelContent level;
  final AdminService service;

  @override
  State<LevelQuestionsScreen> createState() => _LevelQuestionsScreenState();
}

class _LevelQuestionsScreenState extends State<LevelQuestionsScreen> {
  late LevelContent _level = widget.level;

  Future<void> _refresh() async {
    final fresh = await widget.service.levels.getLevel(_level.id);
    if (mounted && fresh != null) setState(() => _level = fresh);
  }

  Future<void> _openEditor([QuizQuestion? question]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuestionEditorScreen(
          level: _level,
          question: question,
          service: widget.service,
        ),
      ),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_level.topicTitle} · Nivel ${_level.level}'),
      ),
      body: _level.questions.isEmpty
          ? const EmptyState(
              icon: Icons.quiz_outlined,
              title: 'Sin preguntas todavía',
              subtitle: 'Añade la primera con el botón de abajo.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _level.questions.length,
              itemBuilder: (context, i) {
                final q = _level.questions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdminCard(
                    padding: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openEditor(q),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AdminColors.tealTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AdminColors.tealDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AdminText.bodyBold,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${q.difficultyLabel} · Correcta: ${q.options[q.correctIndex]}',
                                    style: AdminText.caption,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_outlined,
                              color: AdminColors.faint,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'Añadir pregunta',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Editor de una pregunta: texto, 4 opciones, respuesta correcta y
/// dificultad. Valida antes de guardar (4 opciones, exactamente 1 correcta,
/// texto no vacío).
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.level,
    required this.service,
    this.question,
  });

  final LevelContent level;
  final AdminService service;

  /// null = pregunta nueva.
  final QuizQuestion? question;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late final TextEditingController _textController;
  late final List<TextEditingController> _optionControllers;
  late int _correctIndex;
  late String _difficulty;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _textController = TextEditingController(text: q?.text ?? '');
    _optionControllers = List.generate(
      4,
      (i) => TextEditingController(text: q?.options[i] ?? ''),
    );
    _correctIndex = q?.correctIndex ?? 0;
    _difficulty = q?.difficulty ?? 'facil';
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final question = QuizQuestion(
      id: widget.question?.id ?? '',
      text: _textController.text.trim(),
      options: _optionControllers.map((c) => c.text.trim()).toList(),
      correctIndex: _correctIndex,
      difficulty: _difficulty,
    );
    final error = QuizQuestion.validate(question);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await widget.service.saveQuestion(
        levelId: widget.level.id,
        question: question,
        isNew: widget.question == null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pregunta guardada.')));
        Navigator.of(context).pop(true);
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message as String?;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _busy = false);
        showOfflineNotice(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.question == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Nueva pregunta' : 'Editar pregunta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.level.topicTitle} · Nivel ${widget.level.level}',
            style: AdminText.caption,
          ),
          const SizedBox(height: 16),
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Pregunta',
                    hintText: 'Escribe el enunciado…',
                  ),
                ),
                const SizedBox(height: 20),
                const AdminSectionHeader('OPCIONES (MARCA LA CORRECTA)'),
                RadioGroup<int>(
                  groupValue: _correctIndex,
                  onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                  child: Column(
                    children: List.generate(4, (i) {
                      final selected = _correctIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AdminColors.tealTint
                                : AdminColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AdminColors.teal
                                  : AdminColors.line,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<int>(value: i),
                              Expanded(
                                child: TextField(
                                  controller: _optionControllers[i],
                                  decoration: InputDecoration(
                                    labelText: 'Opción ${i + 1}',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Dificultad'),
                  items: const [
                    DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                    DropdownMenuItem(value: 'media', child: Text('Media')),
                    DropdownMenuItem(value: 'dificil', child: Text('Difícil')),
                  ],
                  onChanged: (v) => setState(() => _difficulty = v ?? 'facil'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.redTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AdminColors.redDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AdminButton.primary(
            label: _busy ? 'Guardando…' : 'Guardar pregunta',
            icon: Icons.save_outlined,
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reportes de preguntas (colección 'reports') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Lista de reportes de preguntas enviados desde la app principal.
/// Permite marcarlos como arreglados.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.reports,
    required this.service,
  });

  final ReportsRepository reports;
  final AdminService service;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<QuestionReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.reports.listReports());
  }

  void _reload() {
    setState(() {
      _future = _guarded(widget.reports.listReports());
    });
  }

  Future<void> _markFixed(QuestionReport report) async {
    try {
      await widget.service.markReportFixed(report);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte marcado como arreglado.')),
        );
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) showOfflineNotice(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes de preguntas')),
      body: FutureBuilder<List<QuestionReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return CalmOfflineState(onRetry: _reload);
          }
          final reports = snap.data ?? [];
          if (reports.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Sin reportes',
              subtitle:
                  'Cuando un usuario reporte una pregunta, aparecerá aquí.',
            );
          }
          final open = reports.where((r) => !r.isFixed).length;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        AdminStatusChip.open(label: '$open abiertos'),
                        const SizedBox(width: 8),
                        AdminStatusChip.done(
                          label: '${reports.length - open} arreglados',
                        ),
                      ],
                    ),
                  );
                }
                final r = reports[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: r.isFixed
                          ? AdminColors.greyTint
                          : AdminColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdminColors.line, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.displayQuestion,
                                  style: AdminText.bodyBold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (r.isFixed)
                                const AdminStatusChip.done(label: 'Arreglado')
                              else
                                const AdminStatusChip.open(label: 'Abierto'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('“${r.note}”', style: AdminText.body),
                          const SizedBox(height: 8),
                          Text(
                            'Por ${r.username} · ${formatDateTime(r.createdAt)}',
                            style: AdminText.caption,
                          ),
                          if (!r.isFixed) ...[
                            const SizedBox(height: 12),
                            AdminButton.primary(
                              label: 'Marcar como arreglado',
                              icon: Icons.check,
                              onPressed: () => _markFixed(r),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Soporte (colección 'support_messages') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Bandeja de Soporte: mensajes de los usuarios (abiertos primero),
/// tocar para leer el mensaje y responder. La respuesta la ve el usuario
/// en su ventanita de Soporte (con aviso en su bandeja).
///
/// La respuesta automática de Muse NO va en esta versión: responde
/// Kristian (o un admin) cuando puede.
class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.support,
    required this.service,
  });

  final SupportRepository support;
  final AdminService service;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<List<SupportMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _guarded(widget.support.listMessages());
  }

  void _reload() {
    setState(() {
      _future = _guarded(widget.support.listMessages());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soporte')),
      body: FutureBuilder<List<SupportMessage>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return CalmOfflineState(onRetry: _reload);
          }
          final messages = snap.data ?? [];
          if (messages.isEmpty) {
            return const EmptyState(
              icon: Icons.support_agent_outlined,
              title: 'Sin mensajes de soporte',
              subtitle:
                  'Cuando un usuario escriba desde la ventanita de Soporte, su mensaje aparecerá aquí.',
            );
          }
          final open = messages.where((m) => !m.isAnswered).length;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$open sin responder · ${messages.length - open} respondido(s)',
                      style: AdminText.caption,
                    ),
                  );
                }
                final m = messages[i - 1];
                final isAnswered = m.isAnswered;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isAnswered
                          ? AdminColors.greyTint
                          : AdminColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdminColors.line, width: 1),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SupportDetailScreen(
                              message: m,
                              service: widget.service,
                            ),
                          ),
                        );
                        _reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AdminUserAvatar(radius: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    m.username,
                                    style: AdminText.bodyBold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isAnswered)
                                  const AdminStatusChip.done(
                                    label: 'Respondido',
                                  )
                                else
                                  const AdminStatusChip.open(label: 'Abierto'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              m.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AdminText.body,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatDateTime(m.createdAt),
                              style: AdminText.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Detalle de un mensaje de soporte: lee el mensaje y responde.
class SupportDetailScreen extends StatefulWidget {
  const SupportDetailScreen({
    super.key,
    required this.message,
    required this.service,
  });

  final SupportMessage message;
  final AdminService service;

  @override
  State<SupportDetailScreen> createState() => _SupportDetailScreenState();
}

class _SupportDetailScreenState extends State<SupportDetailScreen> {
  late SupportMessage _message = widget.message;
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.service.replyToSupport(_message, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respuesta enviada. El usuario la verá en su ventanita.'),
          ),
        );
        setState(() {
          _message = _message.copyWith(
            status: 'respondido',
            reply: text,
            replyAt: DateTime.now(),
          );
          _replyController.clear();
          _sending = false;
        });
      }
    } on PermissionDenied catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _sending = false);
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _sending = false);
      }
    } on Exception {
      if (mounted) {
        showOfflineNotice(context);
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReply = widget.service.me.canManageAdmins();
    return Scaffold(
      appBar: AppBar(title: const Text('Mensaje de soporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const AdminUserAvatar(radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_message.username, style: AdminText.title),
                    Text(
                      formatDateTime(_message.createdAt),
                      style: AdminText.caption,
                    ),
                  ],
                ),
              ),
              if (_message.isAnswered)
                const AdminStatusChip.done(label: 'Respondido')
              else
                const AdminStatusChip.open(label: 'Abierto'),
            ],
          ),
          const SizedBox(height: 16),
          AdminCard(
            child: Text(_message.message, style: AdminText.body),
          ),
          if (_message.isAnswered && _message.reply.isNotEmpty) ...[
            const SizedBox(height: 16),
            const AdminSectionHeader('TU RESPUESTA'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.tealTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.line, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_message.reply, style: AdminText.body),
                  if (_message.replyAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formatDateTime(_message.replyAt!),
                      style: AdminText.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!_message.isAnswered) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('Respuesta de soporte'),
              controller: _replyController,
              enabled: canReply && !_sending,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Escribe tu respuesta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AdminButton.primary(
              label: _sending ? 'Enviando…' : 'Enviar respuesta',
              icon: _sending ? null : Icons.send_outlined,
              leading: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
              onPressed: canReply && !_sending ? _send : null,
            ),
            if (!canReply)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Solo el dueño o un admin con permiso de gestionar administradores puede responder.',
                  textAlign: TextAlign.center,
                  style: AdminText.caption,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
