// Datos de prueba compartidos por todos los tests de Quemia Admin.
//
// 12 usuarios falsos realistas, los mismos en el Panel y en la lista de
// Usuarios, para que las estadísticas se calculen de datos coherentes.

import 'package:quemia_admin/models.dart';

const ownerUid = 'owner-uid-123';
const ownerEmail = 'pozogomezkristian19@gmail.com';

const adminUid = 'admin-uid-456';
const adminEmail = 'ayudante@gmail.com';

AdminRecord ownerRecord() => const AdminRecord(
  uid: ownerUid,
  email: ownerEmail,
  displayName: 'Kristian',
  role: 'owner',
  permissions: AdminPermissions.all,
  createdBy: 'bootstrap',
);

AdminRecord readOnlyAdminRecord() => const AdminRecord(
  uid: adminUid,
  email: adminEmail,
  displayName: 'Ayudante',
  role: 'admin',
  permissions: AdminPermissions.readOnly,
  createdBy: ownerEmail,
);

AppUser _u({
  required String id,
  required String username,
  required int joinedDaysAgo,
  required int lastActiveHoursAgo,
  required int bach,
  required int uni,
  required int points,
  required int streak,
  required String track,
  required String appVersion,
  bool banned = false,
  String bannedReason = '',
  int? bannedDaysAgo,
}) {
  final now = DateTime.now();
  return AppUser(
    id: id,
    username: username,
    joinedAt: now.subtract(Duration(days: joinedDaysAgo)),
    lastActive: now.subtract(Duration(hours: lastActiveHoursAgo)),
    levelsBachPassed: bach,
    levelsUniPassed: uni,
    points: points,
    streak: streak,
    track: track,
    appVersion: appVersion,
    banned: banned,
    bannedReason: bannedReason,
    bannedAt: bannedDaysAgo == null
        ? null
        : now.subtract(Duration(days: bannedDaysAgo)),
  );
}

/// Los 12 usuarios de ejemplo. Niveles ajustados para que el "nivel donde
/// más se atascan" sea Bachillerato · Nivel 6 (laura, miguel, valeria y
/// camila llevan 5 niveles de Bachillerato superados).
List<AppUser> seedUsers() => [
  _u(
    id: 'device-kristian',
    username: 'kristian',
    joinedDaysAgo: 40,
    lastActiveHoursAgo: 2,
    bach: 12,
    uni: 4,
    points: 210,
    streak: 9,
    track: 'uni',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-laura',
    username: 'laura',
    joinedDaysAgo: 28,
    lastActiveHoursAgo: 5,
    bach: 5,
    uni: 0,
    points: 88,
    streak: 5,
    track: 'bach',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-miguel',
    username: 'miguel',
    joinedDaysAgo: 21,
    lastActiveHoursAgo: 1,
    bach: 5,
    uni: 0,
    points: 76,
    streak: 3,
    track: 'bach',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-sofia',
    username: 'sofia',
    joinedDaysAgo: 18,
    lastActiveHoursAgo: 26,
    bach: 10,
    uni: 2,
    points: 165,
    streak: 12,
    track: 'uni',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-daniel',
    username: 'daniel',
    joinedDaysAgo: 15,
    lastActiveHoursAgo: 72,
    bach: 3,
    uni: 0,
    points: 42,
    streak: 0,
    track: 'bach',
    appVersion: '6.2',
  ),
  _u(
    id: 'device-valeria',
    username: 'valeria',
    joinedDaysAgo: 12,
    lastActiveHoursAgo: 0,
    bach: 5,
    uni: 0,
    points: 95,
    streak: 7,
    track: 'bach',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-pedro',
    username: 'pedro',
    joinedDaysAgo: 10,
    lastActiveHoursAgo: 240,
    bach: 7,
    uni: 1,
    points: 90,
    streak: 0,
    track: 'bach',
    appVersion: '6.3',
    banned: true,
    bannedReason: 'Trampas en el examen',
    bannedDaysAgo: 1,
  ),
  _u(
    id: 'device-camila',
    username: 'camila',
    joinedDaysAgo: 8,
    lastActiveHoursAgo: 48,
    bach: 5,
    uni: 0,
    points: 61,
    streak: 1,
    track: 'bach',
    appVersion: '6.2',
  ),
  _u(
    id: 'device-yordanis',
    username: 'yordanis',
    joinedDaysAgo: 6,
    lastActiveHoursAgo: 8,
    bach: 2,
    uni: 0,
    points: 28,
    streak: 2,
    track: 'bach',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-lucia',
    username: 'lucia',
    joinedDaysAgo: 4,
    lastActiveHoursAgo: 4,
    bach: 9,
    uni: 0,
    points: 140,
    streak: 6,
    track: 'bach',
    appVersion: '6.3',
  ),
  _u(
    id: 'device-andres',
    username: 'andres',
    joinedDaysAgo: 2,
    lastActiveHoursAgo: 20,
    bach: 1,
    uni: 0,
    points: 15,
    streak: 1,
    track: 'bach',
    appVersion: '6.2',
  ),
  _u(
    id: 'device-rosa',
    username: 'rosa',
    joinedDaysAgo: 1,
    lastActiveHoursAgo: 12,
    bach: 0,
    uni: 0,
    points: 5,
    streak: 1,
    track: 'bach',
    appVersion: '6.3',
  ),
];

/// Niveles de ejemplo de la colección 'levels' (contenido remoto).
List<LevelContent> seedLevels() {
  final now = DateTime.now();
  return [
    LevelContent(
      id: 'bach-estequiometria-1',
      track: 'bach',
      topic: 'estequiometria',
      topicTitle: 'Estequiometría',
      level: 1,
      title: 'El mol y la masa molar',
      updatedAt: now.subtract(const Duration(days: 3)),
      questions: const [
        QuizQuestion(
          id: 'est-1',
          text: '¿Cuántos moles hay en 36 g de agua (H₂O)?',
          options: ['1 mol', '2 mol', '3 mol', '4 mol'],
          correctIndex: 1,
          difficulty: 'facil',
        ),
        QuizQuestion(
          id: 'est-2',
          text: '¿Cuál es la masa molar del CO₂?',
          options: ['28 g/mol', '32 g/mol', '44 g/mol', '12 g/mol'],
          correctIndex: 2,
          difficulty: 'facil',
        ),
        QuizQuestion(
          id: 'est-3',
          text: 'En la reacción 2H₂ + O₂ → 2H₂O, ¿cuántos moles de agua se forman a partir de 3 moles de H₂?',
          options: ['1,5 mol', '2 mol', '3 mol', '6 mol'],
          correctIndex: 2,
          difficulty: 'media',
        ),
      ],
    ),
    LevelContent(
      id: 'uni-redox-1',
      track: 'uni',
      topic: 'redox',
      topicTitle: 'Reacciones redox',
      level: 1,
      title: 'Números de oxidación',
      updatedAt: now.subtract(const Duration(days: 1)),
      questions: const [
        QuizQuestion(
          id: 'red-1',
          text: '¿Cuál es el número de oxidación del S en H₂SO₄?',
          options: ['+2', '+4', '+6', '-2'],
          correctIndex: 2,
          difficulty: 'media',
        ),
        QuizQuestion(
          id: 'red-2',
          text: 'En Zn + Cu²⁺ → Zn²⁺ + Cu, ¿qué especie se oxida?',
          options: ['Cu²⁺', 'Zn', 'Cu', 'Zn²⁺'],
          correctIndex: 1,
          difficulty: 'facil',
        ),
      ],
    ),
  ];
}

/// Avisos de ejemplo de la colección 'announcements'.
List<Announcement> seedAnnouncements() {
  final now = DateTime.now();
  return [
    Announcement(
      id: 'ann-1',
      title: '¡Nuevo torneo de Estequiometría!',
      body: 'El viernes empieza el torneo de Estequiometría. ¡Prepara tus moles y gana puntos extra!',
      createdAt: now.subtract(const Duration(days: 1)),
      createdBy: ownerEmail,
      active: true,
    ),
    Announcement(
      id: 'ann-2',
      title: 'Mantenimiento el domingo',
      body: 'El domingo por la mañana la app puede ir lenta por mantenimiento.',
      createdAt: now.subtract(const Duration(days: 4)),
      createdBy: ownerEmail,
      active: false,
    ),
  ];
}

/// Mensajes de soporte de ejemplo de la colección 'support_messages'.
/// Dos abiertos (el más reciente es de sofia) y uno ya respondido.
List<SupportMessage> seedSupportMessages() {
  final now = DateTime.now();
  return [
    SupportMessage(
      id: 'sup-1',
      authorUid: 'device-sofia',
      username: 'sofia',
      message: 'No me cargan las preguntas del nivel 3 de Estequiometría, se queda en blanco.',
      createdAt: now.subtract(const Duration(hours: 2)),
      status: 'abierto',
    ),
    SupportMessage(
      id: 'sup-2',
      authorUid: 'device-miguel',
      username: 'miguel',
      message: '¿Cómo recupero mis puntos si cambié de teléfono?',
      createdAt: now.subtract(const Duration(hours: 9)),
      status: 'abierto',
    ),
    SupportMessage(
      id: 'sup-3',
      authorUid: 'device-laura',
      username: 'laura',
      message: 'El examen cronometrado se cerró solo a la mitad.',
      createdAt: now.subtract(const Duration(days: 1)),
      status: 'respondido',
      reply: 'Ya está arreglado, era un fallo al girar la pantalla. ¡Gracias por avisar!',
      replyAt: now.subtract(const Duration(hours: 20)),
    ),
  ];
}

/// Reportes de ejemplo de la colección 'reports'.
/// La pregunta est-3 es la más reportada (3 veces) y red-1 la segunda (2).
List<QuestionReport> seedReports() {
  final now = DateTime.now();
  QuestionReport r(
    String id,
    String questionId,
    String questionText,
    String username,
    String note,
    int hoursAgo,
  ) => QuestionReport(
    id: id,
    questionId: questionId,
    levelId: 'bach-estequiometria-1',
    questionText: questionText,
    username: username,
    note: note,
    createdAt: now.subtract(Duration(hours: hoursAgo)),
    status: 'open',
  );
  return [
    r(
      'rep-1',
      'est-3',
      'En la reacción 2H₂ + O₂ → 2H₂O…',
      'laura',
      'La respuesta que marca como correcta no me cuadra.',
      5,
    ),
    r(
      'rep-2',
      'est-3',
      'En la reacción 2H₂ + O₂ → 2H₂O…',
      'miguel',
      'Creo que hay un error en las opciones.',
      9,
    ),
    r(
      'rep-3',
      'est-3',
      'En la reacción 2H₂ + O₂ → 2H₂O…',
      'sofia',
      'Falta la masa molar en el enunciado.',
      30,
    ),
    r(
      'rep-4',
      'red-1',
      '¿Cuál es el número de oxidación del S en H₂SO₄?',
      'daniel',
      'El signo +6 no aparece como opción.',
      12,
    ),
    r(
      'rep-5',
      'red-1',
      '¿Cuál es el número de oxidación del S en H₂SO₄?',
      'valeria',
      'Yo puse +6 y me la marcó mal.',
      26,
    ),
    QuestionReport(
      id: 'rep-6',
      questionId: 'est-1',
      levelId: 'bach-estequiometria-1',
      questionText: '¿Cuántos moles hay en 36 g de agua (H₂O)?',
      username: 'camila',
      note: 'Ya la arreglaron, gracias.',
      createdAt: now.subtract(const Duration(days: 2)),
      status: 'fixed',
    ),
  ];
}
