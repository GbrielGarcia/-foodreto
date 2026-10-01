import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/failures/notification_failure.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_dto.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestoreCollections.notifications);

  @override
  Future<AppNotification?> getNotification(String id) async {
    final snap = await _col.doc(id).get();
    return NotificationDto.fromMap(snap.id, snap.data());
  }

  @override
  Future<NotificationPage> getNotifications({
    required String recipientUserId,
    int limit = 20,
    String? cursor,
  }) async {
    // Sin orderBy mientras el indice recipientUserId+createdAt termina.
    final snap = await _col
        .where('recipientUserId', isEqualTo: recipientUserId)
        .limit(80)
        .get();
    final items = <AppNotification>[];
    for (final doc in snap.docs) {
      final n = NotificationDto.fromMap(doc.id, doc.data());
      if (n != null) items.add(n);
    }
    items.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      if (c != 0) return c;
      return b.id.compareTo(a.id);
    });

    var start = 0;
    final decoded = NotificationDto.decodeCursor(cursor);
    if (decoded != null) {
      final idx = items.indexWhere(
        (n) =>
            n.createdAt.isBefore(decoded.createdAt) ||
            (n.createdAt.isAtSameMomentAs(decoded.createdAt) &&
                n.id.compareTo(decoded.id) < 0),
      );
      start = idx < 0 ? items.length : idx;
    }
    final slice = items.skip(start).take(limit + 1).toList();
    final hasMore = slice.length > limit;
    final page = hasMore ? slice.sublist(0, limit) : slice;
    return NotificationPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? NotificationDto.encodeCursor(page.last)
          : null,
    );
  }

  @override
  Future<int> getUnreadCount(String recipientUserId) async {
    final snap = await _col
        .where('recipientUserId', isEqualTo: recipientUserId)
        .limit(200)
        .get();
    var n = 0;
    for (final doc in snap.docs) {
      if (doc.data()['read'] != true) n++;
    }
    return n;
  }

  @override
  Stream<int> watchUnreadCount(String recipientUserId) {
    return _col
        .where('recipientUserId', isEqualTo: recipientUserId)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.where((d) => d.data()['read'] != true).length);
  }

  @override
  Future<Result<void>> markAsRead({
    required String notificationId,
    required String recipientUserId,
  }) async {
    try {
      final ref = _col.doc(notificationId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) throw const _NotFound();
        if (data['recipientUserId'] != recipientUserId) {
          throw const _NotAllowed();
        }
        if (data['read'] == true) return;
        tx.update(ref, {'read': true});
      });
      return const Result.success(null);
    } on _NotFound {
      return const Result.failure(NotificationFailure.notFound());
    } on _NotAllowed {
      return const Result.failure(NotificationFailure.notAllowed());
    } catch (e) {
      return Result.failure(
        NotificationFailure.unknown(mapFirestoreError(e).message),
      );
    }
  }

  @override
  Future<Result<int>> markAllAsRead(String recipientUserId) async {
    try {
      final snap = await _col
          .where('recipientUserId', isEqualTo: recipientUserId)
          .limit(500)
          .get();
      final unread =
          snap.docs.where((d) => d.data()['read'] != true).toList();
      var total = 0;
      for (var i = 0; i < unread.length; i += 400) {
        final chunk = unread.skip(i).take(400);
        final batch = _db.batch();
        for (final doc in chunk) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        total += chunk.length;
      }
      return Result.success(total);
    } catch (e) {
      return Result.failure(
        NotificationFailure.unknown(mapFirestoreError(e).message),
      );
    }
  }

  @override
  Future<void> upsert(AppNotification notification) async {
    await _col.doc(notification.id).set(
          {
            ...NotificationDto.toMap(notification),
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          },
          SetOptions(merge: true),
        );
  }
}

class _NotFound implements Exception {
  const _NotFound();
}

class _NotAllowed implements Exception {
  const _NotAllowed();
}
