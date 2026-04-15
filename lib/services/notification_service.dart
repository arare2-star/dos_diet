import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 通知ID: 8時=8, 12時=12, 19時=19
  static const int _morningId = 8;
  static const int _noonId = 12;
  static const int _eveningId = 19;

  static const List<String> _morningMessages = [
    'おい、朝ごはん食べたかぽん？ちゃんと記録するぽん 🌅',
    '朝から記録してこそ本物のダイエットだぽん 🐾',
    '朝食はダイエットの基本ぽん！記録するぽん 🌅',
    '起きたぽん？まず記録からスタートするぽん 🌅',
    '朝の記録をサボるやつはダイエットも失敗するぽん 🐾',
    '今日も始まったぽん。記録する気はあるぽんか？ 🌅',
    'おはようぽん。今日こそちゃんと記録するぽん 🐾',
  ];

  static const List<String> _noonMessages = [
    'もう昼かぽん。記録してるよなぽん？ 🐾',
    '昼食の記録、忘れてないよなぽん？ちゃんとやるぽん ☀️',
    'お昼食べたなら記録するぽん。それがルールだぽん 🐾',
    '今日まだ記録してなくて草ぽん。さっさとやるぽん 🌿',
    '昼になっても無記録とかマジかぽん 😤',
    'お昼ごはん何食べたぽん？記録してないと意味ないぽん ☀️',
    'ぽんぽこ激おこぽん。昼になっても記録ゼロぽん 🔥',
    'もう既にカロリーオーバーwwwwww 知らんぽん 🐾',
    '痩せる気なくて草ぽん。記録くらいしろぽん 🌿',
  ];

  static const List<String> _eveningMessages = [
    '夕食の記録はしたかぽん？1日の締めくくりだぽん 🌙',
    '今日の食事、全部記録できてるか確認するぽん 🐾',
    '夜こそ気を抜くなぽん。記録して今日を終わるぽん 🌙',
    '今日の記録ちゃんとできてるぽん？正直に答えるぽん 🌙',
    '1日お疲れぽん。でも記録してないなら褒めないぽん 🐾',
    '夜ご飯食べたぽん？記録してから寝るぽん 🌙',
    '今日まだ記録してないなら今すぐやるぽん。明日に持ち越すなぽん 🔥',
  ];

  static Future<void> init() async {
    // タイムゾーン初期化（デバイスのローカルタイムゾーンを設定）
    tz.initializeTimeZones();
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

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
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 8時・12時・19時の毎日通知をスケジュール
  static Future<void> scheduleThreeDailyNotifications() async {
    await cancelAllNotifications();

    const androidDetails = AndroidNotificationDetails(
      'ponta_coach_daily',
      'ぽんぽこコーチ（毎日）',
      channelDescription: 'ぽんぽこコーチからの毎日の記録リマインダー',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final seed = DateTime.now().millisecondsSinceEpoch;

    await _plugin.zonedSchedule(
      _morningId,
      'ぽんぽこコーチ 🐾',
      _morningMessages[seed % _morningMessages.length],
      _nextInstanceOfHour(8, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      _noonId,
      'ぽんぽこコーチ 🐾',
      _noonMessages[seed % _noonMessages.length],
      _nextInstanceOfHour(12, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      _eveningId,
      'ぽんぽこコーチ 🐾',
      _eveningMessages[seed % _eveningMessages.length],
      _nextInstanceOfHour(19, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 全通知をキャンセル
  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// 指定した時刻の次のTZDateTimeを取得
  static tz.TZDateTime _nextInstanceOfHour(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// テスト用：即時通知
  static Future<void> showPontaNotification() async {
    const messages = [
      'ごはん記録したかぽん？ 🐾 ぽんぽこが見守ってるぽん！',
      '今日もがんばってるぽん！カロリー記録忘れずにぽん 🐾',
      'ぽんぽこだぽん！食事の記録つけるぽん 🍽️',
      '今日の食事はどうだったぽん？記録するぽん 🐾',
      'ダイエット頑張ってるぽん！ぽんぽこが応援してるぽん 💪🐾',
      '食べたものを記録して、健康的な毎日を送るぽん！ 🐾',
      'ぽんぽこコーチからぽん：今日も食事記録よろしくぽん！ 🐾',
    ];
    final message = messages[DateTime.now().millisecond % messages.length];

    const androidDetails = AndroidNotificationDetails(
      'ponta_coach',
      'ぽんぽこコーチ',
      channelDescription: 'ぽんぽこコーチからの通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(0, 'ぽんぽこコーチ 🐾', message, details);
  }
}
