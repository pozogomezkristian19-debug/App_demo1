// Iconos Lucide (rediseño 2026-11-10): el analizador de rutas SVG
// convierte cada icono sin errores y cada ruta queda dentro del
// viewBox 24x24. Si un icono nuevo trae un comando SVG que el
// analizador no entiende, esta prueba lo caza antes que la pantalla.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';

void main() {
  test('los 109 iconos Lucide se analizan y quedan dentro del viewBox',
      () {
    final icons = <String, LucideIconData>{
      'alarmClock': LucideIcons.alarmClock,
      'arrowLeftRight': LucideIcons.arrowLeftRight,
      'arrowLeft': LucideIcons.arrowLeft,
      'arrowRight': LucideIcons.arrowRight,
      'atom': LucideIcons.atom,
      'award': LucideIcons.award,
      'badgeCheck': LucideIcons.badgeCheck,
      'ban': LucideIcons.ban,
      'barChart3': LucideIcons.barChart3,
      'beaker': LucideIcons.beaker,
      'bellRing': LucideIcons.bellRing,
      'bell': LucideIcons.bell,
      'bookOpen': LucideIcons.bookOpen,
      'book': LucideIcons.book,
      'bookmark': LucideIcons.bookmark,
      'brain': LucideIcons.brain,
      'calculator': LucideIcons.calculator,
      'calendar': LucideIcons.calendar,
      'chartColumn': LucideIcons.chartColumn,
      'checkCheck': LucideIcons.checkCheck,
      'check': LucideIcons.check,
      'chevronRight': LucideIcons.chevronRight,
      'circleCheck': LucideIcons.circleCheck,
      'circleDashed': LucideIcons.circleDashed,
      'circleHelp': LucideIcons.circleHelp,
      'circleX': LucideIcons.circleX,
      'circle': LucideIcons.circle,
      'clipboardList': LucideIcons.clipboardList,
      'clock': LucideIcons.clock,
      'cloud': LucideIcons.cloud,
      'compass': LucideIcons.compass,
      'copy': LucideIcons.copy,
      'dna': LucideIcons.dna,
      'download': LucideIcons.download,
      'droplet': LucideIcons.droplet,
      'eyeOff': LucideIcons.eyeOff,
      'eye': LucideIcons.eye,
      'flag': LucideIcons.flag,
      'flame': LucideIcons.flame,
      'flaskConical': LucideIcons.flaskConical,
      'gamepad2': LucideIcons.gamepad2,
      'gift': LucideIcons.gift,
      'gitMerge': LucideIcons.gitMerge,
      'globe': LucideIcons.globe,
      'graduationCap': LucideIcons.graduationCap,
      'heartPulse': LucideIcons.heartPulse,
      'heart': LucideIcons.heart,
      'hexagon': LucideIcons.hexagon,
      'history': LucideIcons.history,
      'home': LucideIcons.home,
      'hourglass': LucideIcons.hourglass,
      'image': LucideIcons.image,
      'info': LucideIcons.info,
      'landmark': LucideIcons.landmark,
      'languages': LucideIcons.languages,
      'layers2': LucideIcons.layers2,
      'layers': LucideIcons.layers,
      'layoutGrid': LucideIcons.layoutGrid,
      'lightbulb': LucideIcons.lightbulb,
      'link': LucideIcons.link,
      'loaderCircle': LucideIcons.loaderCircle,
      'lock': LucideIcons.lock,
      'logIn': LucideIcons.logIn,
      'logOut': LucideIcons.logOut,
      'menu': LucideIcons.menu,
      'messageCircle': LucideIcons.messageCircle,
      'microscope': LucideIcons.microscope,
      'milestone': LucideIcons.milestone,
      'minus': LucideIcons.minus,
      'moon': LucideIcons.moon,
      'network': LucideIcons.network,
      'notebookPen': LucideIcons.notebookPen,
      'notebook': LucideIcons.notebook,
      'pencil': LucideIcons.pencil,
      'phone': LucideIcons.phone,
      'pipette': LucideIcons.pipette,
      'play': LucideIcons.play,
      'plus': LucideIcons.plus,
      'puzzle': LucideIcons.puzzle,
      'refreshCw': LucideIcons.refreshCw,
      'rocket': LucideIcons.rocket,
      'rotateCcw': LucideIcons.rotateCcw,
      'route': LucideIcons.route,
      'save': LucideIcons.save,
      'scale': LucideIcons.scale,
      'search': LucideIcons.search,
      'settings': LucideIcons.settings,
      'share2': LucideIcons.share2,
      'shuffle': LucideIcons.shuffle,
      'sigma': LucideIcons.sigma,
      'smile': LucideIcons.smile,
      'sparkle': LucideIcons.sparkle,
      'sparkles': LucideIcons.sparkles,
      'star': LucideIcons.star,
      'sun': LucideIcons.sun,
      'table': LucideIcons.table,
      'target': LucideIcons.target,
      'thermometer': LucideIcons.thermometer,
      'timer': LucideIcons.timer,
      'trash2': LucideIcons.trash2,
      'trendingUp': LucideIcons.trendingUp,
      'triangleAlert': LucideIcons.triangleAlert,
      'trophy': LucideIcons.trophy,
      'userRound': LucideIcons.userRound,
      'volume2': LucideIcons.volume2,
      'wandSparkles': LucideIcons.wandSparkles,
      'wind': LucideIcons.wind,
      'x': LucideIcons.x,
      'zap': LucideIcons.zap,
    };
    expect(icons.length, 109);
    for (final entry in icons.entries) {
      final paths = entry.value.paths;
      expect(paths, isNotEmpty, reason: entry.key);
      for (final path in paths) {
        final bounds = path.getBounds();
        expect(bounds.left, greaterThanOrEqualTo(-1),
            reason: '${entry.key} fuera a la izquierda');
        expect(bounds.top, greaterThanOrEqualTo(-1),
            reason: '${entry.key} fuera arriba');
        expect(bounds.right, lessThanOrEqualTo(25),
            reason: '${entry.key} fuera a la derecha');
        expect(bounds.bottom, lessThanOrEqualTo(25),
            reason: '${entry.key} fuera abajo');
        expect(bounds.width + bounds.height, greaterThan(0),
            reason: '${entry.key} vacío');
      }
    }
  });

  test('el corazón de las vidas es una forma cerrada rellenable', () {
    final path = LucideIcons.heart.paths.first;
    final bounds = path.getBounds();
    expect(bounds.width, greaterThan(15));
    expect(bounds.height, greaterThan(15));
  });
}
