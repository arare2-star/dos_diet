import 'package:home_widget/home_widget.dart';

import 'storage_service.dart';

/// 🏠 ホーム画面ウィジェット（ios/PonpokoWidget/）へのデータ受け渡し。
/// App GroupのUserDefaultsに今日の実績を書き、ウィジェットを再描画させる。
/// 通知と同じく、起動時・記録/削除時・目標変更時に呼ぶ
class HomeWidgetService {
  static const _appGroupId = 'group.com.example.dosDiet';
  static const _iosWidgetName = 'PonpokoWidget';

  static Future<void> update(StorageService storage) async {
    try {
      final now = DateTime.now();
      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<int>(
          'total', storage.getTotalCaloriesForDate(now));
      await HomeWidget.saveWidgetData<int>('goal', storage.getCalorieGoal());
      await HomeWidget.saveWidgetData<int>('streak', storage.getStreakDays());
      // ウィジェット側が「今日のデータか」を判定するための日付（yyyy-M-d）
      await HomeWidget.saveWidgetData<String>(
          'date', '${now.year}-${now.month}-${now.day}');
      await HomeWidget.updateWidget(iOSName: _iosWidgetName);
    } catch (_) {
      // ウィジェット未対応環境などで失敗してもアプリ本体には影響させない
    }
  }
}
