// Prueba Ajax en Flutter web (SOLO PRUEBA - no es parte de la app).
// Escucha en vivo el documento settings/app y muestra maintenanceMode y
// maintenanceMessage en cuanto cambian en el servidor, sin recargar.
// El lado admin es el panel de Admin: cambiar el MENSAJE de mantenimiento
// (no el interruptor) y esta página debe actualizarse sola.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.web : null,
  );
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (_) {
    // La lectura puede funcionar igual si las reglas lo permiten.
  }
  runApp(const AjaxTestApp());
}

class AjaxTestApp extends StatelessWidget {
  const AjaxTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba Ajax',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const AjaxTestPage(),
    );
  }
}

class AjaxTestPage extends StatefulWidget {
  const AjaxTestPage({super.key});

  @override
  State<AjaxTestPage> createState() => _AjaxTestPageState();
}

class _AjaxTestPageState extends State<AjaxTestPage> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _clock;
  String _mode = '…';
  String _message = '…';
  String _updated = '—';
  String _now = '—';
  String _error = '';

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _now = _hhmmss(DateTime.now());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = _hhmmss(DateTime.now()));
    });
    _sub = FirebaseFirestore.instance
        .collection('settings')
        .doc('app')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data() ?? {};
      setState(() {
        _mode = data['maintenanceMode'] == true ? 'ON' : 'OFF';
        _message = (data['maintenanceMessage'] ?? '').toString();
        _updated = _hhmmss(DateTime.now());
        _error = '';
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _mode == 'ON';
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba Ajax — en vivo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Esta página se actualiza sola, sin recargar.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escucha el documento settings/app. Cambia el mensaje de mantenimiento en el panel de Admin y debe cambiar aquí solo.',
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Mantenimiento: ',
                                style: TextStyle(fontSize: 18)),
                            Text(
                              _mode,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: on ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Mensaje:',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          _message.isEmpty ? '(vacío)' : _message,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Último cambio del servidor: $_updated'),
                Text('Reloj de la página: $_now'),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
