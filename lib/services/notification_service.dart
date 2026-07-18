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
///
/// 全てカレンダー日付固定の一回きり通知（繰り返しなし）。
/// 以前は最終日の枠だけ`matchDateTimeComponents: DateTimeComponents.time`で
/// 毎日リピートさせていたが、iOS側はこの指定だと日付を無視して「時刻」だけで
/// トリガーするため、次にその時刻が来た瞬間（早ければ即日）から毎日鳴り続けてしまい、
/// 他の日の通常枠と同じ時刻に二重で届く不具合があった（実機で確認済み）。
/// そのため繰り返しはやめ、iOSの1アプリあたり予約通知64件上限に収まる範囲で
/// 先の日付まで一回きり通知を積んでおく方式にしている。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const List<int> _slotHours = [8, 12, 19];
  // iOSは1アプリあたり予約できる通知が最大64件。3枠/日 × 18日 = 54 + 戒め通知1件 = 55で余裕を持たせている
  static const int _daysAhead = 18;

  // 戒めレポート通知（今日オーバー確定時のみ21時に出す）
  static const int _imashimeId = 9000;
  static const int _imashimeHour = 21;

  /// カレンダー上の実日付から一意に決まるid（dayOffset基準にしない）。
  /// dayOffset基準だと「今日」が呼び出しごとに別のidになり、前回組み直し時の枠
  /// （例: 昨日視点の『明日』）が今回のcancelAllで消えなかった場合に古い文面と
  /// 新しい文面が同じ時刻に二重で届くことがあるため、日付から一意に決まるidにして
  /// 取りこぼされても同じidで上書きされるだけにしてある。_imashimeIdの範囲と
  /// 重ならないよう10万を底上げしてある
  static int _stableId(tz.TZDateTime day, int hour) {
    final dayNumber = DateTime(day.year, day.month, day.day)
        .difference(DateTime(2024, 1, 1))
        .inDays;
    final slot = _slotHours.indexOf(hour);
    return 100000 + dayNumber * 10 + slot;
  }

  /// 通知タップ時のハンドラ。main.dartで配線し、payloadに応じて画面を開く
  static void Function(String payload)? onNotificationTap;

  static const List<String> _imashimeNotifBodies = [
    '今日の戒めレポートができたぽん…直視する勇気、あるぽんか 👀',
    '目標オーバー確定ぽん。戒めレポートで反省会するぽん 🔥',
    '本日の戒めレポートが届いてるぽん。逃げずに開くぽん 🐾',
    '本日のやらかし、レポート化完了ぽん。逃げるは恥ぽん 👀',
  ];

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
    '今日もダイエット周回プレイ開始ぽん。初手の記録が大事ぽん 💨',
    '朝から記録すれば今日のお前、優勝ワンチャンあるぽん 🏆',
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
    '夜食は闇のバフぽん（体重に）。手を出したら記録ぽん 👀',
    '記録して寝るまでが今日のクエストぽん 🛏️',
  ];

  // ── 今日用: 実データに基づく文面（組み直し時点の状態が入る） ──────────

  static const List<String> _todayNoRecordNoon = [
    'もう昼ぽん。今日はまだ記録ゼロぽん、そろそろ本気出すぽん 😤',
    '昼になっても無記録ぽん。朝の分も思い出して記録するぽん 🐾',
    '今日まだ記録がないぽん。食べてないなら偉いけど、食べたなら記録ぽん 👀',
    '昼まで無記録は普通に草ぽん。今から巻き返すぽん 🐾',
  ];

  static const List<String> _todayNoRecordEvening = [
    '今日はまだ記録がないぽん。思い出せるうちに入力するぽん 🌙',
    '無記録のまま1日が終わりそうぽん。今からでも間に合うぽん 🔥',
    '今日の記録ゼロぽん…。明日に持ち越す前に今日の分を書くぽん 🐾',
    '記録ゼロは無理ゲーじゃないぽん。1件書けば即クリアぽん 🔥',
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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
  }

  /// アプリが通知タップで起動された場合のpayload（コールドスタート用）。なければnull
  static Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
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

        final id = _stableId(day, hour);

        await _plugin.zonedSchedule(
          id,
          'ぽんぽこコーチ 🐾',
          message,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }

    // 今日すでにオーバー確定なら、21時に戒めレポートの呼び出し通知を出す。
    // 記録・削除のたびに全通知が組み直されるので、オーバーが解消すれば自動で消える
    final today = DateTime.now();
    final total = storage.getTotalCaloriesForDate(today);
    final goal = storage.getCalorieGoal();
    if (goal > 0 && total > goal) {
      final scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, _imashimeHour);
      if (scheduled.isAfter(now)) {
        await _plugin.zonedSchedule(
          _imashimeId,
          'ぽんぽこコーチ 🐾',
          _pick(_imashimeNotifBodies, today.day),
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'imashime:${today.year}-${today.month}-${today.day}',
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

  /// デバッグ用: 登録済み通知の一覧をログに出す
  static Future<void> debugPrintPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      // ignore: avoid_print
      print('[pending] id=${p.id} payload=${p.payload} body=${p.body}');
    }
  }

  /// テスト用：次に届く予定の枠と同じロジック・実データで文面を作り、即時に出す
  static Future<void> showTestNotification(StorageService storage) async {
    final hour = DateTime.now().hour;
    final slot = _slotHours.firstWhere((h) => hour < h,
        orElse: () => _slotHours.last);
    final message = _todayMessage(slot, storage);

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
