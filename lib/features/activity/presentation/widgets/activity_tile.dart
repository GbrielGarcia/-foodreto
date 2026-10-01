import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../domain/entities/social_activity.dart';
import 'activity_copy.dart';

class ActivityTile extends ConsumerWidget {
  const ActivityTile({super.key, required this.activity});

  final SocialActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final cat = activity.categoryId == null
        ? null
        : () {
            for (final c in categories) {
              if (c.id == activity.categoryId) return c;
            }
            return null;
          }();
    final enriched = SocialActivity(
      id: activity.id,
      type: activity.type,
      actorUserId: activity.actorUserId,
      actorUsername: activity.actorUsername,
      actorDisplayName: activity.actorDisplayName,
      actorAvatar: activity.actorAvatar,
      visibility: activity.visibility,
      createdAt: activity.createdAt,
      challengeId: activity.challengeId,
      categoryId: activity.categoryId,
      categoryName: activity.categoryName ?? cat?.name,
      categoryIcon: activity.categoryIcon ?? cat?.icon,
      restaurantId: activity.restaurantId,
      restaurantName: activity.restaurantName,
      score: activity.score,
      previousRecordScore: activity.previousRecordScore,
      scopeKey: activity.scopeKey,
    );

    return InkWell(
      onTap: () {
        final challengeId = activity.challengeId;
        if (challengeId != null && challengeId.isNotEmpty) {
          context.push(AppRoutes.challengePath(challengeId));
        } else {
          context.push(AppRoutes.publicProfilePath(activity.actorUserId));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(
                AppRoutes.publicProfilePath(activity.actorUserId),
              ),
              child: UserAvatar(avatar: activity.actorAvatar, size: 44),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => context.push(
                              AppRoutes.publicProfilePath(activity.actorUserId),
                            ),
                            child: Text(
                              '@${Username.display(activity.actorUsername)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: ' ${ActivityCopy.actionLine(enriched)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ActivityCopy.relativeTime(activity.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
