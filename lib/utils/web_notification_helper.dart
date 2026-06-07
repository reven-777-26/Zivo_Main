import 'web_notification_helper_stub.dart'
    if (dart.library.html) 'web_notification_helper_web.dart';

void showWebNotificationPlatform(String title, String body) {
  showWebNotificationImpl(title, body);
}
