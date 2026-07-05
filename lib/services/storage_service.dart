import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import '../models/weight_entry.dart';

class StorageService {
  late SharedPreferences _prefs;

  static const String _foodEntriesKey = 'food_entries';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationHourKey = 'notification_hour';
  static const String _notificationMinuteKey = 'notification_minute';
  static const String _weightEntriesKey = 'weight_entries';

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

  // 1日合計カロリー目標（食事別の合計。ホーム・統計画面で使用）
  int getCalorieGoal() {
    return getBreakfastGoal() + getLunchGoal() + getDinnerGoal() + getSnackGoal();
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

  // Streak（連続記録日数）

  /// 連続記録日数。今日が未記録でも昨日まで続いていれば維持扱い（まだ途切れていない）
  int getStreakDays() {
    final recorded = getFoodEntries()
        .map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day))
        .toSet();
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!recorded.contains(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (recorded.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ムキムキ判定（ホームのMachoPonta表示条件）

  /// 減量が続いているか: 最新3回の体重記録が単調減少で、最新が7日以内
  bool isWeightTrendingDown() {
    final entries = getWeightEntries()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (entries.length < 3) return false;
    final last3 = entries.sublist(entries.length - 3);
    if (DateTime.now().difference(last3.last.dateTime).inDays > 7) {
      return false;
    }
    return last3[0].weight > last3[1].weight &&
        last3[1].weight > last3[2].weight;
  }

  /// 昨日から遡って「記録あり かつ 合計が目標以内」が何日連続しているか
  int daysWithinGoalStreak() {
    final goal = getCalorieGoal();
    if (goal <= 0) return 0;
    var streak = 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    while (streak < 366) {
      final entries = getFoodEntriesForDate(day);
      if (entries.isEmpty) break;
      final total = entries.fold(0, (sum, e) => sum + e.calories);
      if (total > goal) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 今週（月〜日）の各曜日に記録があるか
  List<bool> getRecordedThisWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        getFoodEntriesForDate(monday.add(Duration(days: i))).isNotEmpty,
    ];
  }
}
