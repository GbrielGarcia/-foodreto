import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/app_notification.dart';

/// Notificaciones del sistema (bandeja + sonido) via plugin local.
///
/// En plan Spark (sin Cloud Functions) no hay FCM push cuando la app esta
/// cerrada. Con la app abierta o en segundo plano, el cliente escucha
/// Firestore y muestra estas notificaciones nativas.
class LocalPushService {
  LocalPushService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  var _ready = false;
  void Function(String? payload)? onTap;

  static const _channelId = 'foodreto_alerts';
  static const _channelName = 'FoodReto';
  static const _channelDesc = 'Solicitudes, retos y records';

  Future<void> init({void Function(String? payload)? onNotificationTap}) async {
    if (kIsWeb || _ready) return;
    onTap = onNotificationTap;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      await android?.requestNotificationsPermission();
    }

    if (!kIsWeb && Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _ready = true;
  }

  Future<void> show(AppNotification n) async {
    if (kIsWeb || !_ready) return;
    final id = n.id.hashCode & 0x7fffffff;
    await _plugin.show(
      id: id,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.social,
          styleInformation: BigTextStyleInformation(n.body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: n.targetRoute ?? '/notifications',
    );
  }
}
