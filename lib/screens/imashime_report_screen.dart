import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/ponta_puppet.dart';
import '../widgets/ui.dart';

/// 🔥 戒めレポート。カロリーオーバーした日の夜に通知が届き、タップでこの画面が開く。
/// 共有機能は持たない自分用の反省会（SNS晒し方向は不採用の経緯あり）
class ImashimeReportScreen extends StatelessWidget {
  final StorageService storageService;
  final DateTime date;

  const ImashimeReportScreen({
    super.key,
    required this.storageService,
    required this.date,
  });

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  /// オーバー度合いに応じた辛口コメント
  List<String> _comments(int over, double ratio) {
    if (ratio < 0.1) {
      return [
        '+${over}kcal、ギリアウトぽん。おしかったぽん、明日は勝てる差ぽん 🔥',
        'ちょいオーバーぽん。この程度なら明日の自分が返せる借金ぽん 🐾',
        'あと一歩だったぽん…。最後の一口が余計だったぽんね 👀',
      ];
    }
    if (ratio < 0.25) {
      return [
        'はっきりオーバーぽん。主犯に心当たりあるぽんね？👀',
        '+${over}kcalは言い逃れできないぽん。でも記録したのは偉いぽん 🐾',
        '今日の分は今日のうちに反省ぽん。明日に持ち越さないぽん 😤',
      ];
    }
    return [
      '完全にやらかしたぽん…。でも正直に記録した勇気は認めるぽん 🐾',
      'ここまでくると逆に清々しいぽん。明日は別人になるぽん 🔥',
      '+${over}kcal…ぽんぽこ、しばらく立ち直れないぽん。一緒に反省するぽん 😱',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = storageService.getFoodEntriesForDate(date);
    final total = entries.fold(0, (sum, e) => sum + e.calories);
    final goal = storageService.getCalorieGoal();
    final over = total - goal;
    final isOver = goal > 0 && over > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: isOver
                ? _buildReport(context, entries, total, goal, over)
                : _buildSafeView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dateLabel = DateFormat('M月d日(E)', 'ja').format(date);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4E342E), Color(0xFF6D4C41)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '戒めレポート 🔥',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  dateLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(
    BuildContext context,
    List<FoodEntry> entries,
    int total,
    int goal,
    int over,
  ) {
    final ratio = over / goal;
    final comments = _comments(over, ratio);
    final comment = comments[date.day % comments.length];

    // 主犯: その日いちばんカロリーが高かった一品
    final culprit = entries.reduce(
      (a, b) => a.calories >= b.calories ? a : b,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          const PontaPuppet(size: 120, expression: PontaExpression.cry),
          const SizedBox(height: 12),
          Text(
            comment,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '+$over',
            style: GoogleFonts.nunito(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: AppTheme.danger,
              height: 1.0,
            ),
          ),
          Text(
            'kcal オーバー（目標 $goal / 実績 $total）',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日の内訳',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                for (final type in _mealTypes)
                  MealProgressRow(
                    type: type,
                    calories: entries
                        .where((e) => e.type == type)
                        .fold(0, (sum, e) => sum + e.calories),
                    goal: storageService.getMealGoal(type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                MealIcon(type: culprit.type, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本日の主犯 👮',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        culprit.name,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${culprit.calories}kcal',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('明日リベンジするぽん 🔥'),
            ),
          ),
        ],
      ),
    );
  }

  /// 通知後に記録が削除されてオーバーが解消していた場合のフォールバック
  Widget _buildSafeView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PontaPuppet(size: 120, expression: PontaExpression.wink),
            const SizedBox(height: 16),
            Text(
              'あれ、セーフになってるぽん。\n戒めることは何もないぽん ✨',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('とじる'),
            ),
          ],
        ),
      ),
    );
  }
}
