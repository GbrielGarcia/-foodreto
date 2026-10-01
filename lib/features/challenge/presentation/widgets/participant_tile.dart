import 'package:flutter/material.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// Fila de participante: avatar, nombre, @username y lo que se indique a la
/// derecha (contador, medalla…).
class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    super.key,
    required this.avatar,
    required this.displayName,
    required this.username,
    this.isHost = false,
    this.isMe = false,
    this.leading,
    this.trailing,
    this.highlight = false,
  });

  final AvatarConfig avatar;
  final String displayName;
  final String username;
  final bool isHost;
  final bool isMe;
  final Widget? leading;
  final Widget? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = [if (isMe) 'Tú', if (isHost) 'Anfitrión'];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: highlight
            ? Border.all(color: scheme.primary.withValues(alpha: 0.45))
            : null,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
          UserAvatar(avatar: avatar, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    '@$username',
                    ...tags,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
