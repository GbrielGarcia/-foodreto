import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/notification_dto.dart';
import '../../data/services/local_push_service.dart';

final localPushServiceProvider = Provider<LocalPushService>((ref) {
  return LocalPushService();
});

/// Escucha notificaciones nuevas del usuario y las muestra en el sistema.
final systemNotificationBridgeProvider = Provider<void>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.backendMode != BackendMode.firebase || kIsWeb) return;

  final uid = ref.watch(authStateProvider).value?.id;
  if (uid == null) return;

  final service = ref.watch(localPushServiceProvider);
  final db = ref.watch(firestoreProvider);
  final router = ref.watch(routerProvider);

  var primed = false;
  final seen = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

  Future<void> start() async {
    await service.init(
      onNotificationTap: (payload) {
        final route = (payload == null || payload.isEmpty)
            ? AppRoutes.notifications
            : payload;
        router.push(route);
      },
    );

    sub = db
        .collection(FirestoreCollections.notifications)
        .where('recipientUserId', isEqualTo: uid)
        .limit(15)
        .snapshots()
        .listen((snap) async {
      if (!primed) {
        for (final doc in snap.docs) {
          seen.add(doc.id);
        }
        primed = true;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        if (!seen.add(id)) continue;
        final n = NotificationDto.fromMap(id, change.doc.data());
        if (n == null || n.read) continue;
        await service.show(n);
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('FoodReto: system notification bridge error: $e');
    });
  }

  unawaited(start());
  ref.onDispose(() {
    unawaited(sub?.cancel() ?? Future<void>.value());
  });
});
