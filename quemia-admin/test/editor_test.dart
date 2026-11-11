// Editor de contenido: validación de preguntas y guardado en el nivel.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

const validQuestion = QuizQuestion(
  id: 'est-1',
  text: '¿Cuántos moles hay en 36 g de agua (H₂O)?',
  options: ['1 mol', '2 mol', '3 mol', '4 mol'],
  correctIndex: 1,
  difficulty: 'facil',
);

AdminService serviceFor(AdminRecord me) => AdminService(
  me: me,
  users: FakeUsersRepository(),
  admins: FakeAdminsRepository(),
  settings: FakeSettingsRepository(),
  levels: FakeLevelsRepository(seedLevels()),
);

void main() {
  group('validación del editor', () {
    test('una pregunta válida pasa', () {
      expect(QuizQuestion.validate(validQuestion), isNull);
    });

    test('texto vacío no pasa', () {
      expect(
        QuizQuestion.validate(validQuestion.copyWith(text: '   ')),
        'La pregunta no puede estar vacía.',
      );
    });

    test('menos de 4 opciones no pasa', () {
      expect(
        QuizQuestion.validate(validQuestion.copyWith(options: ['a', 'b', 'c'])),
        'La pregunta debe tener exactamente 4 opciones.',
      );
    });

    test('una opción vacía no pasa', () {
      expect(
        QuizQuestion.validate(
          validQuestion.copyWith(options: ['1 mol', '', '3 mol', '4 mol']),
        ),
        'Ninguna opción puede estar vacía.',
      );
    });

    test('opciones repetidas no pasan', () {
      expect(
        QuizQuestion.validate(
          validQuestion.copyWith(options: ['2 mol', '2 mol', '3 mol', '4 mol']),
        ),
        'Las 4 opciones deben ser distintas.',
      );
    });

    test('índice correcto fuera de rango no pasa', () {
      expect(
        QuizQuestion.validate(validQuestion.copyWith(correctIndex: 4)),
        'Hay que marcar exactamente una respuesta correcta.',
      );
    });

    test('dificultad desconocida no pasa', () {
      expect(
        QuizQuestion.validate(validQuestion.copyWith(difficulty: 'extrema')),
        'La dificultad debe ser fácil, media o difícil.',
      );
    });
  });

  group('guardado en el nivel', () {
    test('editar una pregunta existente la sustituye', () async {
      final service = serviceFor(ownerRecord());
      await service.saveQuestion(
        levelId: 'bach-estequiometria-1',
        question: validQuestion.copyWith(
          text: '¿Cuántos moles hay en 18 g de agua (H₂O)?',
          correctIndex: 0,
          options: ['1 mol', '2 mol', '3 mol', '4 mol'],
        ),
      );
      final level = (await service.levels.getLevel('bach-estequiometria-1'))!;
      expect(level.questions.length, 3);
      final edited = level.questions.firstWhere((q) => q.id == 'est-1');
      expect(edited.text, '¿Cuántos moles hay en 18 g de agua (H₂O)?');
      expect(edited.correctIndex, 0);
    });

    test('añadir una pregunta nueva la agrega al nivel', () async {
      final service = serviceFor(ownerRecord());
      await service.saveQuestion(
        levelId: 'bach-estequiometria-1',
        question: const QuizQuestion(
          id: '',
          text: '¿Qué es un mol?',
          options: [
            'Una unidad de masa',
            'Una cantidad de sustancia',
            'Un tipo de átomo',
            'Una unidad de volumen',
          ],
          correctIndex: 1,
          difficulty: 'facil',
        ),
        isNew: true,
      );
      final level = (await service.levels.getLevel('bach-estequiometria-1'))!;
      expect(level.questions.length, 4);
      expect(level.questions.last.text, '¿Qué es un mol?');
      expect(level.questions.last.id, isNotEmpty);
    });

    test('una pregunta inválida NO se guarda', () async {
      final service = serviceFor(ownerRecord());
      await expectLater(
        service.saveQuestion(
          levelId: 'bach-estequiometria-1',
          question: validQuestion.copyWith(text: ''),
        ),
        throwsArgumentError,
      );
      final level = (await service.levels.getLevel('bach-estequiometria-1'))!;
      expect(level.questions.length, 3);
    });

    test('nivel inexistente NO se guarda', () async {
      final service = serviceFor(ownerRecord());
      await expectLater(
        service.saveQuestion(levelId: 'no-existe', question: validQuestion),
        throwsArgumentError,
      );
    });

    test('admin sin manageAdmins NO puede editar contenido', () async {
      final service = serviceFor(readOnlyAdminRecord());
      await expectLater(
        service.saveQuestion(
          levelId: 'bach-estequiometria-1',
          question: validQuestion,
        ),
        throwsA(isA<PermissionDenied>()),
      );
    });
  });
}
