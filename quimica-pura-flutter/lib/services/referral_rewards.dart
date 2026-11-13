// Recompensas de referidos (Quemia 7.3): los artículos que se
// desbloquean invitando amigos. NO se venden en la tienda
// (referralOnly: la Tienda los esconde): solo se consiguen por
// hitos de referidos, con [SocialService.grantItem].
//
// Las fotos de los dos avatares son assets empaquetados (como los
// premium de la 7.0), así que equiparlas funciona sin internet y
// sin esperar a que se publiquen los documentos en Firestore.
// Los documentos de 'shop_items' con estos mismos ids están listos
// en REFERRALS_FIRESTORE.md (semilla, sin publicar): cuando se
// publiquen, el catálogo remoto los traerá y el respaldo local de
// aquí seguirá resolviendo igual (el remoto manda por id).
import 'shop_item.dart';

/// Un hito de referidos: al llegar a [count] referidos
/// confirmados, se regalan [rewards] y [bonusPoints] puntos.
class ReferralMilestone {
  const ReferralMilestone({
    required this.count,
    required this.rewards,
    this.bonusPoints = 0,
  });

  final int count;
  final List<ShopItem> rewards;
  final int bonusPoints;
}

/// Avatar Embajador (hito 3): traje teal con banda dorada y
/// medalla. Foto 512x512 generada en el estilo 3D de los
/// avatares premium.
const ShopItem kAvatarEmbajador = ShopItem(
  id: 'avatar_embajador',
  name: 'Embajador',
  kind: 'avatar',
  price: 0,
  color: 0xFF8B5CF6,
  asset: 'assets/avatar_embajador.png',
  description:
      'El embajador de Quemia. Solo se consigue invitando amigos.',
  referralOnly: true,
  sortOrder: 100,
);

/// Tema Embajador (hito 5): acento dorado para toda la app.
const ShopItem kThemeEmbajador = ShopItem(
  id: 'theme_embajador',
  name: 'Embajador',
  kind: 'theme',
  price: 0,
  color: 0xFFF59E0B,
  description: 'Dorado como un embajador. Solo invitando amigos.',
  referralOnly: true,
  sortOrder: 101,
);

/// Insignia Embajador (hito 5): trofeo dorado para el perfil.
const ShopItem kBadgeEmbajador = ShopItem(
  id: 'badge_embajador',
  name: 'Embajador',
  kind: 'badge',
  price: 0,
  color: 0xFFFFC800,
  badgeIcon: 'trophy',
  description: 'Trofeo de embajador. Solo invitando amigos.',
  referralOnly: true,
  sortOrder: 102,
);

/// Avatar Leyenda (hito 10): corona de laureles dorada y
/// emblema de matraz. Foto 512x512 generada en el estilo 3D de
/// los avatares premium.
const ShopItem kAvatarLeyenda = ShopItem(
  id: 'avatar_leyenda',
  name: 'Leyenda',
  kind: 'avatar',
  price: 0,
  color: 0xFFFFC800,
  asset: 'assets/avatar_leyenda.png',
  description:
      'Una leyenda de la química. Solo los que invitan a 10 amigos.',
  referralOnly: true,
  sortOrder: 103,
);

/// Todos los artículos de recompensa, para resolverlos en local
/// (SocialService._lookupCatalog los incluye: así el tema, el
/// avatar y la insignia se equipan y se ven aunque el catálogo
/// remoto aún no los traiga).
const List<ShopItem> kReferralRewardItems = [
  kAvatarEmbajador,
  kThemeEmbajador,
  kBadgeEmbajador,
  kAvatarLeyenda,
];

/// Los tres hitos, en orden: 3, 5 y 10 referidos confirmados.
const List<ReferralMilestone> kReferralMilestones = [
  ReferralMilestone(count: 3, rewards: [kAvatarEmbajador]),
  ReferralMilestone(
    count: 5,
    rewards: [kThemeEmbajador, kBadgeEmbajador],
  ),
  ReferralMilestone(
    count: 10,
    rewards: [kAvatarLeyenda],
    bonusPoints: 200,
  ),
];

/// El artículo de recompensa con [id], o null si no es uno.
ShopItem? referralRewardItem(String id) {
  for (final item in kReferralRewardItems) {
    if (item.id == id) return item;
  }
  return null;
}
