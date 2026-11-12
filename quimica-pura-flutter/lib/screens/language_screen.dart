// Pantalla de idioma (v5): su propia pantalla, con su banderita cada
// idioma. Antes los idiomas eran una lista suelta dentro del menú
// hamburguesa; ahora el menú solo enlaza aquí.

import '../data/i18n/content_i18n.dart';
import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../widgets/flags.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('languageWord'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('obLangTitle'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(tr('obLangBody')),
          const SizedBox(height: 16),
          for (final (code, name) in AppLang.supported)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shadowColor:
                  const Color(0xFF00C2A8).withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: FlagWidget(code: code),
                title: Text(name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle: Text(code == 'es'
                    ? 'Español'
                    : code == 'en'
                        ? 'English'
                        : code == 'fr'
                            ? 'Français'
                            : code == 'it'
                                ? 'Italiano'
                                : code == 'pt'
                                    ? 'Português'
                                    : 'Русский'),
                trailing: AppLang.code == code
                    ? LucideIcon(LucideIcons.circleCheck,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () async {
                  await AppLang.setLang(code);
                    syncGeneratorLang();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'El contenido de estudio y las preguntas siguen en español; los menús y botones se traducen al idioma elegido.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
