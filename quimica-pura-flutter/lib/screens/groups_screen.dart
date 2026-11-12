// Grupos de estudio (Quemia 7.0): crear un grupo (nombre + código
// de invitación) o unirse con el código; la pantalla del grupo
// muestra el progreso de los miembros (niveles, puntos, racha).
// Sin chat. Sin Google, la puerta.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/social_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/social_avatar.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  var _online = true;
  String? _createdCode;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    SocialService.online.then((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final group = await SocialService.createGroup(name);
    if (!mounted || group == null) return;
    setState(() {
      _createdCode = group.inviteCode;
      _nameCtrl.clear();
    });
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    final group = await SocialService.joinGroup(code);
    if (!mounted) return;
    if (group == null) {
      setState(() => _joinError = tr('groupsJoinNotFound'));
      return;
    }
    setState(() => _joinError = null);
    _open(group);
  }

  void _open(StudyGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupDetailScreen(
          groupId: group.id,
          isGoogleLinked: widget.isGoogleLinked,
          onLinkGoogle: widget.onLinkGoogle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const teal = Color(0xFF00C2A8);
    return Scaffold(
      appBar: AppBar(title: Text(tr('groupsTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                elevation: 3,
                shadowColor: teal.withValues(alpha: 0.22),
                color:
                    isDark ? scheme.surfaceContainerHighest : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Formulario apilado (ronda de diseño 7.0): el
                      // campo arriba y el botón a ancho completo
                      // debajo. En una fila el botón largo
                      // ("Unirse con código") dejaba el campo sin
                      // ancho y desbordaba; apilado cabe siempre.
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          hintText: tr('groupsCreateHint'),
                          // Borde teal claro (sistema Quemia), no
                          // el gris oscuro por defecto.
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFF00C2A8)
                                  .withValues(alpha: 0.40),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFF00C2A8)
                                  .withValues(alpha: 0.40),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF00C2A8),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _create(),
                      ),
                      const SizedBox(height: 10),
                      // Píldora 3D teal con degradado + brillo.
                      DuoButton.primary(
                        label: tr('groupsCreate').toUpperCase(),
                        onPressed: _create,
                        fontSize: 15,
                      ),
                      if (_createdCode != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${tr('groupsCode').replaceFirst('%s', _createdCode!)} — ${tr('groupsCreated')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeCtrl,
                        decoration: InputDecoration(
                          hintText: tr('groupsJoinHint'),
                          // Borde teal claro (sistema Quemia), no
                          // el gris oscuro por defecto.
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFF00C2A8)
                                  .withValues(alpha: 0.40),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFF00C2A8)
                                  .withValues(alpha: 0.40),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF00C2A8),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _join(),
                      ),
                      const SizedBox(height: 10),
                      // Píldora blanca 3D (DuoButton.secondary).
                      DuoButton.secondary(
                        label: tr('groupsJoin').toUpperCase(),
                        onPressed: _join,
                        textColor: const Color(0xFF00A18D),
                        edgeColor: const Color(0xFF99E9DB),
                        fontSize: 15,
                      ),
                      if (_joinError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _joinError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !_online
                  ? _CalmLine(text: tr('socialOffline'))
                  : FutureBuilder<List<StudyGroup>>(
                      future: SocialService.groups(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final groups = snapshot.data ?? [];
                        if (groups.isEmpty) {
                          return _EmptyGroups(scheme: scheme);
                        }
                        return ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final g = groups[index];
                            return _GroupRow(
                              group: g,
                              isDark: isDark,
                              scheme: scheme,
                              onTap: () => _open(g),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalmLine extends StatelessWidget {
  const _CalmLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C2A8).withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.network,
                size: 34,
                color: Color(0xFF00C2A8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('groupsEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.isDark,
    required this.scheme,
    required this.onTap,
  });

  final StudyGroup group;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: const Color(0xFF00C2A8).withValues(alpha: 0.18),
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF7F7F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C2A8).withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.network,
                  size: 22,
                  color: Color(0xFF00C2A8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tr('groupsMembers').replaceFirst('%s', '${group.members.length}')} · ${tr('groupsCode').replaceFirst('%s', group.inviteCode)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const LucideIcon(
                LucideIcons.chevronRight,
                size: 20,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle del grupo: progreso de los miembros.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final String groupId;
  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(tr('groupsTitle'))),
      body: OnlineGate(
        isGoogleLinked: isGoogleLinked,
        onLinkGoogle: onLinkGoogle,
        child: FutureBuilder<List<StudyGroup>>(
          future: SocialService.groups(),
          builder: (context, snapshot) {
            final groups = snapshot.data ?? [];
            final group =
                groups.where((g) => g.id == groupId).firstOrNull;
            if (group == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  elevation: 3,
                  shadowColor: const Color(0xFF00C2A8).withValues(alpha: 0.22),
                  color:
                      isDark ? scheme.surfaceContainerHighest : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('groupsCode')
                              .replaceFirst('%s', group.inviteCode),
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final m in group.members)
                  _MemberRow(member: m, isDark: isDark, scheme: scheme),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await SocialService.leaveGroup(group.id);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: const LucideIcon(LucideIcons.logOut, size: 18),
                  label: Text(tr('groupsLeave')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isDark,
    required this.scheme,
  });

  final FriendEntry member;
  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: const Color(0xFF00C2A8).withValues(alpha: 0.18),
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF7F7F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            SocialAvatar(
              username: member.username,
              avatarAsset: member.avatarAsset,
              badgeId: member.badgeId,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.username,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tr('lbLevels')} ${member.levelsPassedTotal} · '
                    '${tr('pointsWord')} ${member.points} · '
                    '${tr('streakWord')} ${member.streak}',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
