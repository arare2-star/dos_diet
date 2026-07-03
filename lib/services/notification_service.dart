import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'storage_service.dart';

/// ぽんぽこコーチの通知。
///
/// ローカル通知は配信時点のアプリ状態を知れないため、
/// 「アプリ起動時・食事の記録/削除時・設定変更時」に毎回全通知を組み直す方式にしている。
/// - 今日の残り枠: その時点の実データ（合計kcal・目標・記録の有無）から文面を生成。
///   記録するたびに組み直されるので、内容が実態とズレない
/// - 明日以降の枠: 状態を断定しない汎用メッセージを日替わりでローテーション
/// - 最終日(7日目)の枠だけ毎日リピートにして、アプリを開かない期間が続いても通知が途切れないようにする
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const List<int> _slotHours = [8, 12, 19];
  static const int _daysAhead = 7;

  // ── 明日以降用: 記録状態に触れない汎用メッセージ ──────────────────

  static const List<String> _genericMorning = [
    'おはようぽん。今日も「食べたら記録」が合言葉ぽん 🌅',
    '朝ごはんを食べたらすぐ記録するぽん。後回しは忘れるぽん 🐾',
    '朝を制する者はダイエットを制するぽん 🌅',
    '起きたぽんか？今日も一緒にがんばるぽん 🐾',
    '今日の一食目、食べたら忘れず記録ぽん 🍚',
    '記録は朝が肝心ぽん。スタートダッシュ決めるぽん 💨',
    '今日の目標カロリー、覚えてるぽんか？意識して1日を始めるぽん 🌅',
    '朝の1タップが夜の後悔を防ぐぽん。記録するぽん 🐾',
  ];

  static const List<String> _genericNoon = [
    'お昼の時間ぽん。食べたら記録も忘れずにぽん ☀️',
    'ランチ何食べるぽん？記録する前提で選ぶと賢いぽん 🐾',
    '昼食の記録はお済みぽんか？まだなら今のうちぽん ☀️',
    '午後もがんばるために、まずお昼の記録ぽん 💪',
    'カロリーは逃げないけど記憶は逃げるぽん。早めに記録ぽん 🌿',
    '食べてから時間が経つと忘れるぽん。お昼のうちに記録ぽん 🐾',
    '昼食を記録すれば午後の作戦が立てられるぽん ☀️',
  ];

  static const List<String> _genericEvening = [
    '夕食の時間ぽん。記録までが食事ぽん 🌙',
    '今日の記録、抜けてる食事はないぽんか？寝る前にチェックぽん 🐾',
    '夜は油断しがちぽん。食べたら正直に記録するぽん 🌙',
    '1日お疲れぽん。今日の分を記録して気持ちよく寝るぽん 🛏️',
    '間食もこっそり食べたなら記録するぽん。ぽんぽこは見てるぽん 👀',
    '夕食を記録したら今日のミッション完了ぽん 🌙',
    '今日を記録で締めくくるぽん。明日の自分が助かるぽん 🐾',
  ];

  // ── 今日用: 実データに基づく文面（組み直し時点の状態が入る） ──────────

  static const List<String> _todayNoRecordNoon = [
    'もう昼ぽん。今日はまだ記録ゼロぽん、そろそろ本気出すぽん 😤',
    '昼になっても無記録ぽん。朝の分も思い出して記録するぽん 🐾',
    '今日まだ記録がないぽん。食べてないなら偉いけど、食べたなら記録ぽん 👀',
  ];

  static const List<String> _todayNoRecordEvening = [
    '今日はまだ記録がないぽん。思い出せるうちに入力するぽん 🌙',
    '無記録のまま1日が終わりそうぽん。今からでも間に合うぽん 🔥',
    '今日の記録ゼロぽん…。明日に持ち越す前に今日の分を書くぽん 🐾',
  ];

  static List<String> _todayOverMessages(int total, int goal) => [
        '現時点で$totalカロリーぽん。目標の$goalをもうオーバーぽん…この後は控えめにぽん 🔥',
        '今日は$totalカロリーで目標オーバーぽん。挽回はここからの選択次第ぽん 🐾',
        '目標$goalに対して今$totalぽん。今日はもう打ち止めにするぽん 😤',
      ];

  static List<String> _todayOnTrackMessages(int total, int remaining) => [
        'ここまで$totalカロリー、残り$remainingぽん。いいペースぽん ☀️',
        '今日は$totalカロリー記録済みぽん。あと$remaining使えるぽん 🐾',
        '順調ぽん！合計$totalカロリー、目標まであと$remainingぽん ✨',
      ];

  static const List<String> _todayMorningRecorded = [
    '朝から記録済みとは、今日のお前は一味違うぽん ✨',
    'もう記録してるぽんか。ぽんぽこ、感心したぽん 🐾',
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

  /// 全通知を現在の記録状態に合わせて組み直す。
  /// アプリ起動時・食事の記録/削除時・目標変更時・通知オン時に呼ぶ。
  static Future<void> reschedule(StorageService storage) async {
    await cancelAllNotifications();
    if (!storage.getNotificationsEnabled()) return;

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

    final now = tz.TZDateTime.now(tz.local);

    for (var dayOffset = 0; dayOffset < _daysAhead; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      for (final hour in _slotHours) {
        final scheduled =
            tz.TZDateTime(tz.local, day.year, day.month, day.day, hour);
        if (scheduled.isBefore(now)) continue; // 今日の過ぎた枠はスキップ

        final message = dayOffset == 0
            ? _todayMessage(hour, storage)
            : _genericMessage(hour, scheduled);

        // 最終日だけ毎日リピートにして、組み直しが走らない期間のフォールバックにする
        final isFallback = dayOffset == _daysAhead - 1;

        await _plugin.zonedSchedule(
          dayOffset * 100 + hour,
          'ぽんぽこコーチ 🐾',
          message,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents:
              isFallback ? DateTimeComponents.time : null,
        );
      }
    }
  }

  /// 今日の枠: 組み直し時点の実データから文面を作る
  static String _todayMessage(int hour, StorageService storage) {
    final today = DateTime.now();
    final total = storage.getTotalCaloriesForDate(today);
    final goal = storage.getCalorieGoal();
    final hasRecords = storage.getFoodEntriesForDate(today).isNotEmpty;
    final salt = today.day;

    if (hour == 8) {
      // 朝の時点で未記録なのは普通なので、煽らず汎用メッセージ
      return hasRecords
          ? _pick(_todayMorningRecorded, salt)
          : _pick(_genericMorning, salt);
    }
    if (!hasRecords) {
      // ストリークが懸かっているときはそれを最優先で煽る
      final streak = storage.getStreakDays();
      if (streak >= 2) {
        return hour == 12
            ? 'まだ無記録ぽん。$streak日ストリークが懸かってるぽん🔥'
            : 'このまま寝たら$streak日ストリークが消滅するぽん！1件でいいから記録するぽん🔥';
      }
      return _pick(
        hour == 12 ? _todayNoRecordNoon : _todayNoRecordEvening,
        salt,
      );
    }
    if (goal > 0 && total > goal) {
      return _pick(_todayOverMessages(total, goal), salt);
    }
    if (goal > 0) {
      return _pick(_todayOnTrackMessages(total, goal - total), salt);
    }
    return _pick(hour == 12 ? _genericNoon : _genericEvening, salt);
  }

  /// 明日以降の枠: 日替わりで汎用メッセージをローテーション
  static String _genericMessage(int hour, tz.TZDateTime date) {
    final pool = switch (hour) {
      8 => _genericMorning,
      12 => _genericNoon,
      _ => _genericEvening,
    };
    final dayOfYear =
        DateTime(date.year, date.month, date.day)
            .difference(DateTime(date.year))
            .inDays;
    return _pick(pool, dayOfYear);
  }

  static String _pick(List<String> pool, int salt) =>
      pool[salt % pool.length];

  /// 全通知をキャンセル
  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
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
