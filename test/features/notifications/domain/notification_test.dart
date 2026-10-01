import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/notifications/data/models/notification_dto.dart';
import 'package:foodreto/features/notifications/data/repositories/in_memory_notification_repository.dart';
import 'package:foodreto/features/notifications/domain/entities/app_notification.dart';
import 'package:foodreto/features/notifications/domain/entities/notification_type.dart';
import 'package:foodreto/features/notifications/domain/failures/notification_failure.dart';
import 'package:foodreto/features/notifications/domain/services/notification_deep_link.dart';
import 'package:foodreto/features/notifications/domain/services/notification_ids.dart';

AvatarConfig get _av => const AvatarConfig(
      style: 'lorelei',
      seed: 's',
      options: {'backgroundColor': 'ffc53d'},
    );

AppNotification _n(
  String id, {
  required String recipient,
  required DateTime at,
  bool read = false,
  NotificationType type = NotificationType.friendRequest,
  String actor = 'bob',
}) =>
    AppNotification(
      id: id,
      recipientUserId: recipient,
      type: type,
      actorUserId: actor,
      actorUsername: actor,
      actorDisplayName: actor,
      actorAvatar: _av,
      title: 't',
      body: 'b',
      read: read,
      createdAt: at,
      challengeId: type == NotificationType.challengeWon ? 'c1' : null,
    );

void main() {
  group('NotificationType / IDs', () {
    test('parse', () {
      expect(
        NotificationType.tryParse('challengeWon'),
        NotificationType.challengeWon,
      );
      expect(NotificationType.friendRequest.isOfficial, isFalse);
      expect(NotificationType.recordBroken.isOfficial, isTrue);
    });

    test('ids deterministic', () {
      expect(NotificationIds.friendRequest('a_b'), 'friendRequest_a_b');
      expect(
        NotificationIds.challengeWon('c1', 'u1'),
        'challengeWon_c1_u1',
      );
      expect(
        NotificationIds.friendJoined(
          challengeId: 'c',
          actorUserId: 'a',
          recipientUserId: 'r',
        ),
        'friendJoined_c_a_r',
      );
    });
  });

  group('NotificationDto', () {
    test('roundtrip', () {
      final n = _n('friendRequest_x', recipient: 'me', at: DateTime.utc(2026));
      final map = NotificationDto.toMap(n);
      final back = NotificationDto.fromMap(n.id, {
        ...map,
        'createdAt': n.createdAt,
        'actorAvatarOptions': n.actorAvatar.options,
      });
      expect(back?.recipientUserId, 'me');
      expect(back?.type, NotificationType.friendRequest);
      expect(back?.read, isFalse);
    });

    test('invalid -> null', () {
      expect(NotificationDto.fromMap('x', null), isNull);
      expect(NotificationDto.fromMap('x', {'type': 'nope'}), isNull);
    });
  });

  group('DeepLink', () {
    test('resolves routes', () {
      expect(
        NotificationDeepLink.resolve(
          _n('1', recipient: 'me', at: DateTime.utc(2026)),
        ),
        '/friends/requests',
      );
      expect(
        NotificationDeepLink.resolve(
          _n(
            '2',
            recipient: 'me',
            at: DateTime.utc(2026),
            type: NotificationType.challengeWon,
          ),
        ),
        '/challenges/c1',
      );
    });
  });

  group('InMemoryNotificationRepository', () {
    late InMemoryNotificationRepository repo;

    setUp(() {
      repo = InMemoryNotificationRepository();
      final t0 = DateTime.utc(2026, 2, 1);
      repo.seed(_n('a', recipient: 'me', at: t0.add(const Duration(hours: 2))));
      repo.seed(_n('b', recipient: 'me', at: t0.add(const Duration(hours: 1))));
      repo.seed(_n('c', recipient: 'other', at: t0));
      repo.seed(
        _n('d', recipient: 'me', at: t0, read: true),
      );
    });

    tearDown(() {
      repo.dispose();
    });

    test('pagination and isolation', () async {
      final page = await repo.getNotifications(
        recipientUserId: 'me',
        limit: 2,
      );
      expect(page.items.length, 2);
      expect(page.items.every((n) => n.recipientUserId == 'me'), isTrue);
      expect(page.hasMore, isTrue);
      final page2 = await repo.getNotifications(
        recipientUserId: 'me',
        limit: 2,
        cursor: page.nextCursor,
      );
      expect(
        page.items.map((e) => e.id).toSet().intersection(
              page2.items.map((e) => e.id).toSet(),
            ),
        isEmpty,
      );
    });

    test('unread count and mark read', () async {
      expect(await repo.getUnreadCount('me'), 2);
      final r = await repo.markAsRead(
        notificationId: 'a',
        recipientUserId: 'me',
      );
      expect(r, isA<Success<void>>());
      expect(await repo.getUnreadCount('me'), 1);

      final denied = await repo.markAsRead(
        notificationId: 'c',
        recipientUserId: 'me',
      );
      expect(
        denied.fold(onSuccess: (_) => null, onFailure: (f) => f),
        isA<NotificationNotAllowed>(),
      );
    });

    test('mark all read', () async {
      final r = await repo.markAllAsRead('me');
      expect(r.fold(onSuccess: (c) => c, onFailure: (_) => -1), 2);
      expect(await repo.getUnreadCount('me'), 0);
    });

    test('upsert idempotent', () async {
      final n = _n('a', recipient: 'me', at: DateTime.utc(2026));
      await repo.upsert(n.copyWith(read: true));
      final got = await repo.getNotification('a');
      expect(got?.read, isFalse); // putIfAbsent keeps first
    });
  });
}
