// Quemia Admin — panel de administración de la app Quemia.
//
// Inicio defensivo: si Firebase no se puede inicializar (por ejemplo, si
// falta android/app/google-services.json), la app muestra una pantalla clara
// "Falta configurar Firebase" en vez de romperse.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'push_service.dart';
import 'repositories.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseError;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    firebaseError = '$e';
  }
  if (firebaseError == null) {
    // Receptor de pushes FCM del panel: nunca bloquea ni rompe el arranque
    // (PushService.init() traga cualquier fallo). El token solo se guarda
    // después, desde HomeShell, cuando el admin ya está verificado.
    unawaited(PushService.shared.init());
  }
  runApp(QuemiaAdminApp(firebaseError: firebaseError));
}

class QuemiaAdminApp extends StatelessWidget {
  const QuemiaAdminApp({super.key, this.firebaseError});

  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quemia Admin',
      theme: quemiaAdminTheme(),
      home: firebaseError != null
          ? FirebaseMissingScreen(error: firebaseError!)
          : const AuthGate(),
    );
  }
}

/// Puerta de auth:
///  - sin sesión -> pantalla de login con Google.
///  - con sesión pero sin documento en 'admins' -> "No tienes acceso".
///  - con documento -> panel principal.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService, this.admins});

  final GoogleAuthService? authService;
  final AdminsRepository? admins;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final GoogleAuthService _auth =
      widget.authService ?? GoogleAuthService();
  late final AdminsRepository _admins =
      widget.admins ?? FirestoreAdminsRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = authSnap.data;
        if (user == null) {
          return SignInScreen(authService: _auth);
        }
        return FutureBuilder(
          future: resolveAdminRecord(
            admins: _admins,
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
          ),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Sin conexión al resolver el admin: estado tranquilo con
            // reintento, NUNCA la pantalla de "No tienes acceso" (el fallo
            // es de red, no de permisos) ni un diálogo de error.
            if (adminSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Quemia Admin')),
                body: CalmOfflineState(onRetry: () => setState(() {})),
              );
            }
            final admin = adminSnap.data;
            if (admin == null) {
              return NoAccessScreen(
                email: user.email ?? 'sin correo',
                uid: user.uid,
                authService: _auth,
              );
            }
            return HomeShell(me: admin, authService: _auth);
          },
        );
      },
    );
  }
}
