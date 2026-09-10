import 'package:flutter/foundation.dart';
import 'notification_base.dart';

class NotificationWeb implements NotificationBase {
  @override
  Future<void> init() async {
    debugPrint("Web Notifications: Initialized stub");
  }

  @override
  Future<void> showNotification({required String title, required String body}) async {
    debugPrint("WEB NOTIFICATION: $title - $body");
  }
}

NotificationBase getNotificationService() => NotificationWeb();
