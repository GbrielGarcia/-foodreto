import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/services/notification_deep_link.dart';
import '../providers/notification_providers.dart';

abstract final class NotificationCopy {
  static String relativeTime(DateTime at, {DateTime? now}) {
    final n = now ?? DateTime.now().toUtc();
    final d = n.difference(at.toUtc());
    if (d.inSeconds < 60) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays < 7) return 'hace ${d.inDays} d';
    return '${at.day}/${at.month}/${at.year}';
  }
}

class NotificationTile extends ConsumerWidget {
  const NotificationTile({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = notification;
    final unread = !n.read;

    return InkWell(
      onTap: () async {
        final route = NotificationDeepLink.resolve(n);
        // No bloquear navegacion si falla el marcado.
        try {
          await ref
              .read(notificationsControllerProvider.notifier)
              .markRead(n.id);
        } catch (_) {}
        if (!context.mounted) return;
        if (route != null && route.isNotEmpty) {
          context.push(route);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: unread
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(avatar: n.actorAvatar, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body.isNotEmpty
                        ? n.body
                        : '@${Username.display(n.actorUsername)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NotificationCopy.relativeTime(n.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm, top: 6),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
