import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local push notifications for outage / low reserve / firmware alerts.
class NotificationService {
  NotificationService({this.enabled = true});
  final bool enabled;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  static const _channel = AndroidNotificationDetails(
    'aether_alerts',
    'Power Core alerts',
    channelDescription: 'Grid outages, low reserve and firmware updates.',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF7CE3B9),
  );

  Future<void> init() async {
    if (!enabled || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true, badge: true);
  }

  Future<void> show(String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: _id++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
    );
  }
}
