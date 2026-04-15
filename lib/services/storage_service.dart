import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import '../models/weight_entry.dart';

class StorageService {
  late SharedPreferences _prefs;

  static const String _foodEntriesKey = 'food_entries';
  static const String _calorieGoalKey = 'calorie_goal';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationHourKey = 'notification_hour';
  static const String _notificationMinuteKey = 'notification_minute';
  static const String _weightEntriesKey = 'weight_entries';
  static const String _firstScanDateKey = 'first_scan_date';
  static const String _isPremiumKey = 'is_premium';

  // 食事別カロリー目標キー
  static const String _breakfastGoalKey = 'breakfast_goal';
  static const String _lunchGoalKey = 'lunch_goal';
  static const String _dinnerGoalKey = 'dinner_goal';
  static const String _snackGoalKey = 'snack_goal';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 食事別カロリー目標（デフォルト値：合計2000kcal相当）
  int getBreakfastGoal() => _prefs.getInt(_breakfastGoalKey) ?? 500;  // 朝食
  int getLunchGoal()     => _prefs.getInt(_lunchGoalKey)     ?? 700;  // 昼食
  int getDinnerGoal()    => _prefs.getInt(_dinnerGoalKey)    ?? 600;  // 夕食
  int getSnackGoal()     => _prefs.getInt(_snackGoalKey)     ?? 200;  // おやつ

  /// 食事タイプ文字列から目標カロリーを取得
  int getMealGoal(String type) {
    switch (type) {
      case 'breakfast': return getBreakfastGoal();
      case 'lunch':     return getLunchGoal();
      case 'dinner':    return getDinnerGoal();
      case 'snack':     return getSnackGoal();
      default:          return 600;
    }
  }

  Future<void> setMealGoal(String type, int goal) async {
    switch (type) {
      case 'breakfast': await _prefs.setInt(_breakfastGoalKey, goal); break;
      case 'lunch':     await _prefs.setInt(_lunchGoalKey,     goal); break;
      case 'dinner':    await _prefs.setInt(_dinnerGoalKey,    goal); break;
      case 'snack':     await _prefs.setInt(_snackGoalKey,     goal); break;
    }
  }

  // ---- トライアル・プレミアム管理 ----

  // 初回スキャン日時を取得（未使用ならnull）
  DateTime? getFirstScanDate() {
    final ms = _prefs.getInt(_firstScanDateKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  // 初回スキャン日時を記録（初回のみ）
  Future<void> recordFirstScanIfNeeded() async {
    if (_prefs.getInt(_firstScanDateKey) == null) {
      await _prefs.setInt(
        _firstScanDateKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  // トライアル期間内かどうか（初回スキャンから3日以内）
  bool isTrialActive() {
    final first = getFirstScanDate();
    if (first == null) return true; // まだ一度もスキャンしていない
    return DateTime.now().difference(first).inDays < 3;
  }

  // プレミアム購入済みかどうか
  bool getIsPremium() => _prefs.getBool(_isPremiumKey) ?? false;

  Future<void> setIsPremium(bool value) async {
    await _prefs.setBool(_isPremiumKey, value);
  }

  // スキャン機能が使えるか（トライアル中 or プレミアム）
  bool canUseScan() => isTrialActive() || getIsPremium();

  // トライアル残り日数
  int trialDaysRemaining() {
    final first = getFirstScanDate();
    if (first == null) return 3;
    final diff = DateTime.now().difference(first).inDays;
    return (3 - diff).clamp(0, 3);
  }

  // 1日合計カロリー目標（食事別の合計。ホーム・統計画面で使用）
  int getCalorieGoal() {
    // 食事別目標が設定されている場合はその合計を使う
    final sum = getBreakfastGoal() + getLunchGoal() + getDinnerGoal() + getSnackGoal();
    // 旧設定が残っている場合は食事別合計を優先
    return sum;
  }

  // 旧APIとの互換性のため残す（今後は setMealGoal を使うこと）
  Future<void> setCalorieGoal(int goal) async {
    await _prefs.setInt(_calorieGoalKey, goal);
  }

  // Notifications
  bool getNotificationsEnabled() =>
      _prefs.getBool(_notificationsEnabledKey) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  int getNotificationHour() => _prefs.getInt(_notificationHourKey) ?? 20;

  int getNotificationMinute() => _prefs.getInt(_notificationMinuteKey) ?? 0;

  Future<void> setNotificationTime(int hour, int minute) async {
    await _prefs.setInt(_notificationHourKey, hour);
    await _prefs.setInt(_notificationMinuteKey, minute);
  }

  // Food Entries
  List<FoodEntry> getFoodEntries() {
    final jsonString = _prefs.getString(_foodEntriesKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((item) => FoodEntry.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFoodEntries(List<FoodEntry> entries) async {
    final jsonList = entries.map((e) => e.toMap()).toList();
    await _prefs.setString(_foodEntriesKey, json.encode(jsonList));
  }

  Future<void> addFoodEntry(FoodEntry entry) async {
    final entries = getFoodEntries();
    entries.add(entry);
    await saveFoodEntries(entries);
  }

  Future<void> removeFoodEntry(String id) async {
    final entries = getFoodEntries();
    entries.removeWhere((e) => e.id == id);
    await saveFoodEntries(entries);
  }

  // Weight Entries
  List<WeightEntry> getWeightEntries() {
    final jsonString = _prefs.getString(_weightEntriesKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((item) => WeightEntry.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveWeightEntries(List<WeightEntry> entries) async {
    final jsonList = entries.map((e) => e.toMap()).toList();
    await _prefs.setString(_weightEntriesKey, json.encode(jsonList));
  }

  Future<void> addOrUpdateWeightEntry(WeightEntry entry) async {
    final entries = getWeightEntries();
    // 同じ日のエントリーがあれば上書き
    entries.removeWhere((e) =>
        e.dateTime.year == entry.dateTime.year &&
        e.dateTime.month == entry.dateTime.month &&
        e.dateTime.day == entry.dateTime.day);
    entries.add(entry);
    await saveWeightEntries(entries);
  }

  WeightEntry? getWeightForDate(DateTime date) {
    final entries = getWeightEntries();
    try {
      return entries.firstWhere((e) =>
          e.dateTime.year == date.year &&
          e.dateTime.month == date.month &&
          e.dateTime.day == date.day);
    } catch (_) {
      return null;
    }
  }

  List<WeightEntry> getWeightEntriesForRange(DateTime start, DateTime end) {
    final entries = getWeightEntries();
    return entries
        .where((e) =>
            !e.dateTime.isBefore(start) && !e.dateTime.isAfter(end))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<FoodEntry> getFoodEntriesForDate(DateTime date) {
    final entries = getFoodEntries();
    return entries.where((e) {
      return e.dateTime.year == date.year &&
          e.dateTime.month == date.month &&
          e.dateTime.day == date.day;
    }).toList();
  }

  int getTotalCaloriesForDate(DateTime date) {
    final entries = getFoodEntriesForDate(date);
    return entries.fold(0, (sum, e) => sum + e.calories);
  }
}
