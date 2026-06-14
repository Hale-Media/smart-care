import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps flutter_local_notifications for alert push on shared devices.
/// No Firebase dependency by default (zero ongoing cost); a real-time
/// transport (FCM or websockets) can be layered on later.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _initialised = true;
  }

  Future<void> showAlert({
    required int id,
    required String title,
    required String body,
    bool critical = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      critical ? 'critical_alerts' : 'alerts',
      critical ? 'Critical Alerts' : 'Alerts',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: critical,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
    );
  }
}
