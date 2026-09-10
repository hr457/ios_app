import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'notification_base.dart';

class NotificationMobile implements NotificationBase {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      // In latest versions (v22+), initialize might use named parameters exclusively
      await (_notificationsPlugin as dynamic).initialize(
        initializationSettings: initializationSettings,
      );
    } catch (e) {
      try {
        // Fallback for different plugin versions
        await (_notificationsPlugin as dynamic).initialize(initializationSettings);
      } catch (e2) {
        debugPrint("Notification Initialization failed: $e2");
      }
    }
  }

  @override
  Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'safl_channel', 
      'SAFL Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      // In latest versions (v22+), show might use named parameters exclusively
      await (_notificationsPlugin as dynamic).show(
        id: DateTime.now().millisecond % 10000,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      try {
        // Fallback for different plugin versions
        await (_notificationsPlugin as dynamic).show(
          DateTime.now().millisecond % 10000,
          title,
          body,
          platformChannelSpecifics,
        );
      } catch (e2) {
        debugPrint("Notification Show failed: $e2");
      }
    }
  }
}

NotificationBase getNotificationService() => NotificationMobile();
