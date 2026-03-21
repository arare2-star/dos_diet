import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const List<String> _pontaMessages = [
    'ごはん記録した？ 🐾 ぽんたが見守ってるよ！',
    '今日もがんばってるね！カロリー記録忘れずに 🐾',
    'ぽんただよ！食事の記録つけてね 🍽️',
    '今日の食事はどうだった？記録しよう 🐾',
    'ダイエット頑張ってるね！ぽんたが応援してるよ 💪🐾',
    '食べたものを記録して、健康的な毎日を！ 🐾',
    'ぽんたコーチより：今日も食事記録よろしくね！ 🐾',
  ];

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showPontaNotification() async {
    final message =
        _pontaMessages[DateTime.now().millisecond % _pontaMessages.length];

    const androidDetails = AndroidNotificationDetails(
      'ponta_coach',
      'ぽんたコーチ',
      channelDescription: 'ぽんたコーチからの通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0,
      'ぽんたコーチ 🐾',
      message,
      details,
    );
  }
}
