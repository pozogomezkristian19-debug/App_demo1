// Hoja "Reportar pregunta" (Quemia 7.0): opción pequeña y discreta
// bajo las opciones de una pregunta (regla 1: solo este texto, sin
// banners ni nada online en las pantallas de estudio). Tres
// motivos; se envía en silencio y se agradece con una sola línea.
// La usan el SimpleQuizRunner (duelos, torneos, examen con tiempo)
// y el _QuizRunner de niveles/repaso (practicar_screen.dart).

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/social_service.dart';

Future<void> showReportQuestionSheet(
  BuildContext context,
  String questionId,
) {
  final reasons = [
    tr('reportReasonWrong'),
    tr('reportReasonUnclear'),
    tr('reportReasonData'),
  ];
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                tr('reportReasonTitle'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final reason in reasons)
              ListTile(
                key: ValueKey('report-reason-$reason'),
                title: Text(reason),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(
                      SocialService.reportQuestion(questionId, reason));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('reportThanks'))),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Botón discreto "Reportar" para poner bajo las opciones de una
/// pregunta: 13 px, gris, alineado a la derecha.
class ReportQuestionButton extends StatelessWidget {
  const ReportQuestionButton({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        key: const ValueKey('report-question'),
        onPressed: () => showReportQuestionSheet(context, questionId),
        child: Text(
          tr('reportTitle'),
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
