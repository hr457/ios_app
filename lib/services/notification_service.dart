import 'notification_base.dart';
import 'notification_web.dart' if (dart.library.io) 'notification_mobile.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final NotificationBase _service = getNotificationService();

  Future<void> init() async {
    await _service.init();
  }

  Future<void> showNotification({required String title, required String body}) async {
    await _service.showNotification(title: title, body: body);
  }
}
