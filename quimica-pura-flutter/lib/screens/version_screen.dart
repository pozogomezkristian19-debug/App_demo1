// Cambiar versión (v5): Bachillerato o Universidad, en su propia
// pantalla del menú. Al cambiar, se muestra una transición de carga
// corta y se reconstruye toda la app con la versión nueva (como si
// cambiara la app entera). La elección se guarda en el teléfono.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import '../services/user_prefs.dart';

class VersionScreen extends StatefulWidget {
  const VersionScreen({super.key, required this.onVersionChanged});
  final VoidCallback onVersionChanged;

  @override
  State<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends State<VersionScreen> {
  bool _changing = false;

  Future<void> _change(String t) async {
    if (t == ProgressService.track || _changing) return;
    setState(() => _changing = true);
    // Transición de carga: se siente como cambiar de app.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Cambiando de versión…')),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // cierra el diálogo
    await ProgressService.setTrack(t);
    await UserPrefs.saveTrack(t);
    widget.onVersionChanged(); // reconstruye la app con la versión nueva
    if (!mounted) return;
    Navigator.of(context).pop(); // vuelve a Niveles
  }

  @override
  Widget build(BuildContext context) {
    final current = ProgressService.track;
    return Scaffold(
      appBar: AppBar(title: Text(tr('versionTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Elige la versión de la app. Cada versión tiene sus temas, sus niveles y su progreso guardado: cambiar no borra nada.',
          ),
          const SizedBox(height: 16),
          _versionCard(
            context,
            value: ProgressService.trackBach,
            title: tr('trackBach'),
            body: 'Para preuniversitario: estequiometría básica, disoluciones, gases y ácido-base, con su examen final de 16 preguntas.',
            icon: LucideIcons.graduationCap,
            selected: current == ProgressService.trackBach,
          ),
          const SizedBox(height: 10),
          _versionCard(
            context,
            value: ProgressService.trackUni,
            title: tr('trackUni'),
            body: 'Más difícil: 8 temas más Orgánica y Laboratorio, con el examen final de 24 preguntas.',
            icon: LucideIcons.landmark,
            selected: current == ProgressService.trackUni,
          ),
        ],
      ),
    );
  }

  Widget _versionCard(
    BuildContext context, {
    required String value,
    required String title,
    required String body,
    required LucideIconData icon,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primary.withValues(alpha: 0.15) : null,
      elevation: selected ? 3 : 2,
      shadowColor: const Color(0xFF00C2A8).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.18),
          child: LucideIcon(icon, color: scheme.primary),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(body),
        trailing: selected
            ? LucideIcon(LucideIcons.circleCheck, color: scheme.primary)
            : const LucideIcon(LucideIcons.chevronRight),
        onTap: _changing ? null : () => _change(value),
      ),
    );
  }
}
