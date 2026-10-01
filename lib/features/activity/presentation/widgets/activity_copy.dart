import '../../domain/entities/social_activity.dart';
import '../../domain/entities/social_activity_type.dart';

abstract final class ActivityCopy {
  static String actionLine(SocialActivity a) {
    final cat = _categoryLabel(a);
    final place = a.restaurantName != null && a.restaurantName!.isNotEmpty
        ? ' en ${a.restaurantName}'
        : '';
    final score = a.score;
    return switch (a.type) {
      SocialActivityType.challengeCompleted =>
        'complet\u00f3 un reto$cat$place',
      SocialActivityType.challengeWon => score != null
          ? 'gan\u00f3 un reto$cat con $score'
          : 'gan\u00f3 un reto$cat$place',
      SocialActivityType.recordCreated =>
        'consigui\u00f3 un nuevo r\u00e9cord$cat',
      SocialActivityType.recordBroken =>
        'super\u00f3 el r\u00e9cord$cat',
      SocialActivityType.friendJoinedChallenge =>
        'se uni\u00f3 a un reto$cat$place',
    };
  }

  static String _categoryLabel(SocialActivity a) {
    final icon = a.categoryIcon;
    final name = a.categoryName;
    if (icon != null && name != null) return ' de $icon $name';
    if (name != null) return ' de $name';
    if (icon != null) return ' de $icon';
    return '';
  }

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
