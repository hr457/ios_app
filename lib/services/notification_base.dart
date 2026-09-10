abstract class NotificationBase {
  Future<void> init();
  Future<void> showNotification({required String title, required String body});
}
