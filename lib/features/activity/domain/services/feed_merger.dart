import '../entities/social_activity.dart';

/// Fusiona páginas de consultas parciales (amigos / público), deduplica y ordena.
abstract final class FeedMerger {
  /// Orden: `createdAt` DESC, luego `id` ASC (estable ante empates de tiempo).
  static int compare(SocialActivity a, SocialActivity b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  }

  /// Deduplica por [SocialActivity.id] y ordena.
  static List<SocialActivity> dedupeAndSort(Iterable<SocialActivity> input) {
    final byId = <String, SocialActivity>{};
    for (final a in input) {
      byId.putIfAbsent(a.id, () => a);
    }
    return byId.values.toList()..sort(compare);
  }

  /// Toma hasta [limit] tras dedupe; [seenIds] evita repetir entre páginas.
  static ({List<SocialActivity> items, Set<String> seen}) takePage({
    required Iterable<SocialActivity> candidates,
    required Set<String> seenIds,
    required int limit,
  }) {
    final sorted = dedupeAndSort(candidates);
    final out = <SocialActivity>[];
    final seen = {...seenIds};
    for (final a in sorted) {
      if (seen.contains(a.id)) continue;
      seen.add(a.id);
      out.add(a);
      if (out.length >= limit) break;
    }
    return (items: out, seen: seen);
  }
}

/// Cursor compuesto `createdAtMs_id` para paginación estable.
abstract final class ActivityCursor {
  static String encode(DateTime createdAt, String id) =>
      '${createdAt.toUtc().millisecondsSinceEpoch}_$id';

  static ({DateTime createdAt, String id})? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final sep = raw.indexOf('_');
    if (sep <= 0) return null;
    final ms = int.tryParse(raw.substring(0, sep));
    final id = raw.substring(sep + 1);
    if (ms == null || id.isEmpty) return null;
    return (
      createdAt: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      id: id,
    );
  }
}
