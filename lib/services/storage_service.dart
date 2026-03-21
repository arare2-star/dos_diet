import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';

class StorageService {
  late SharedPreferences _prefs;

  static const String _foodEntriesKey = 'food_entries';
  static const String _calorieGoalKey = 'calorie_goal';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationHourKey = 'notification_hour';
  static const String _notificationMinuteKey = 'notification_minute';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Calorie Goal
  int getCalorieGoal() => _prefs.getInt(_calorieGoalKey) ?? 2000;

  Future<void> setCalorieGoal(int goal) async {
    await _prefs.setInt(_calorieGoalKey, goal);
  }

  // Notifications
  bool getNotificationsEnabled() =>
      _prefs.getBool(_notificationsEnabledKey) ?? false;

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
