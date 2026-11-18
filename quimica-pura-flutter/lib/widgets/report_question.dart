// Hoja "Reportar pregunta" (Quemia 7.0): opción pequeña y discreta
// bajo las opciones de una pregunta (regla 1: solo este texto, sin
// banners ni nada online en las pantallas de estudio). Tres
// motivos; se envía en silencio y se agradece con una sola línea.
// La usan el SimpleQuizRunner (duelos, torneos, examen con tiempo)
// y el _QuizRunner de niveles/repaso (practicar_screen.dart).
//
// 2026-11-17 (Kristian): debajo de los 3 motivos hay un «Otro»;
// al tocarlo sale una caja de texto para escribir un mensaje corto
// (máx. 140 caracteres, con contador) que viaja con el reporte.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/social_service.dart';
import '../widgets/duo_button.dart';

/// Largo máximo del mensaje de «Otro»: corto, como pidió Kristian.
const int kReportOtherMaxLength = 140;

Future<void> showReportQuestionSheet(
  BuildContext context,
  String questionId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) =>
        _ReportQuestionSheet(questionId: questionId),
  );
}

class _ReportQuestionSheet extends StatefulWidget {
  const _ReportQuestionSheet({required this.questionId});

  final String questionId;

  @override
  State<_ReportQuestionSheet> createState() => _ReportQuestionSheetState();
}

class _ReportQuestionSheetState extends State<_ReportQuestionSheet> {
  /// ¿Está abierto «Otro» con su caja de texto?
  bool _showOther = false;

  final _messageController = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Envía el reporte ([note] es el motivo o el mensaje de «Otro»)
  /// y agradece con una sola línea, como antes.
  Future<void> _send(String note) async {
    if (_sending) return;
    _sending = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    unawaited(SocialService.reportQuestion(widget.questionId, note));
    messenger.showSnackBar(
      SnackBar(content: Text(tr('reportThanks'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [
      tr('reportReasonWrong'),
      tr('reportReasonUnclear'),
      tr('reportReasonData'),
    ];
    final otherOpen = _showOther;
    final canSend = _messageController.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        // Que el teclado no tape la caja de texto.
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
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
                  onTap: () => _send(reason),
                ),
              ListTile(
                key: const ValueKey('report-reason-other'),
                title: Text(tr('reportReasonOther')),
                trailing: Icon(
                  otherOpen ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => setState(() => _showOther = !otherOpen),
              ),
              if (otherOpen) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: TextField(
                    key: const ValueKey('report-other-field'),
                    controller: _messageController,
                    maxLength: kReportOtherMaxLength,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: tr('reportOtherHint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: DuoButton.primary(
                      label: tr('reportSend').toUpperCase(),
                      onPressed: canSend
                          ? () => _send(_messageController.text.trim())
                          : null,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
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
