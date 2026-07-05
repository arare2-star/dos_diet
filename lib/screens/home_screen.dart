import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/food_entry.dart';
import '../theme.dart';
import '../widgets/ponta_puppet.dart';
import '../widgets/macho_ponta.dart';
import '../widgets/share_card.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onAddFood;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.onAddFood,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late int _calorieGoal;
  late int _todayCalories;
  late List<FoodEntry> _todayEntries;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() {
      _calorieGoal = widget.storageService.getCalorieGoal();
      final today = DateTime.now();
      _todayEntries = widget.storageService.getFoodEntriesForDate(today);
      _todayCalories = widget.storageService.getTotalCaloriesForDate(today);
    });
  }

  /// ムキムキ条件: 減量が続いている or 目標カロリー以内が5日連続。
  /// ただし今日すでにオーバーしていたら説得力がないので解除
  bool _isMacho() {
    if (_calorieGoal > 0 && _todayCalories > _calorieGoal) return false;
    return widget.storageService.isWeightTrendingDown() ||
        widget.storageService.daysWithinGoalStreak() >= 5;
  }

  String _getMachoMessage() {
    const pool = [
      '見ろぽん、この仕上がり💪 継続の賜物ぽん。',
      '努力は筋肉に出るぽん💪 今のお前は強いぽん。',
      '仕上がってるぽん💪 この調子で維持するぽん。',
    ];
    return pool[(DateTime.now().day + _todayCalories) % pool.length];
  }

  String _getPontaMessage() {
    final ratio = _todayCalories / _calorieGoal;
    final List<String> pool;
    if (_todayCalories == 0) {
      pool = [
        'さっさと記録するぽん。始めないと意味ないぽん。',
        '無記録は普通に草ぽん。とりあえず1件入れるぽん。',
        '今日のお前、まだ透明人間ぽん（記録ゼロ）。',
        '記録なし＝食べてないは通用しないぽん。正直に書くぽん。',
      ];
    } else if (ratio <= 0.5) {
      pool = [
        'おっ、やるじゃないかぽん！その調子で続けるぽん！',
        '順調すぎて逆に怖いぽん。何か企んでるぽん？',
        'この調子なら今日のお前、優勝ぽん🏆',
        '有能すぎるぽん。ぽんぽこ、ちょっと感動してるぽん。',
      ];
    } else if (ratio < 0.8) {
      pool = [
        'まあ悪くはないぽん。油断すんなよぽん。',
        'ここからが本番ぽん。夜のお前は信用してないぽん。',
        '今のところセーフぽん。夜食だけはマジでやめるぽん。',
      ];
    } else if (ratio < 1.0) {
      pool = [
        'ギリギリだぽん。あと少し、踏ん張るぽん。',
        '残りHPわずかぽん。ここで食べたら即死ぽん。',
        '瀬戸際ぽん。冷蔵庫に近づくの禁止ぽん。',
      ];
    } else if (ratio < 1.2) {
      pool = [
        'オーバーしてるじゃないかぽん。反省するぽん。',
        'はい、オーバー。言い訳は聞かないぽん。',
        'オーバーしたのは事実ぽん。でも記録したお前は偉いぽん。',
      ];
    } else {
      pool = [
        'はあ？食いすぎだぽん。明日からやり直すぽん。',
        'もう笑うしかないぽん。明日の自分に謝っとくぽん。',
        'ここまで食ったら逆に清々しいぽん。明日リセットぽん。',
      ];
    }
    // 日替わり＋合計値で変わる（同じ状態のうちは同じセリフで安定させる）
    return pool[(DateTime.now().day + _todayCalories) % pool.length];
  }

  @override
  Widget build(BuildContext context) {
    final progress = _todayCalories / _calorieGoal;
    final remaining = _calorieGoal - _todayCalories;
    final dateStr = DateFormat('M月d日（E）', 'ja').format(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(dateStr),
          // ぽんぽこカードをヘッダーに重ねて奥行きを出す
          // （translateはレイアウト位置を変えないため、余白はヘッダー側と下端paddingで調整）
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              // 下端はFABに隠れないよう余白を広めに取る
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 66),
              child: Column(
                children: [
                  _buildPontaCard(),
                  const SizedBox(height: 16),
                  StreakBar(
                    streak: widget.storageService.getStreakDays(),
                    weekRecorded: widget.storageService.getRecordedThisWeek(),
                    recordedToday: _todayEntries.isNotEmpty,
                  ),
                  const SizedBox(height: 16),
                  _buildCalorieCard(progress, remaining),
                  const SizedBox(height: 16),
                  _buildMealSummary(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String dateStr) {
    return GradientHeader(
      title: 'ぽんぽこ',
      subtitle: dateStr,
      bottomPadding: 48, // ぽんぽこカードが重なるぶん深めに取る
      trailing: IconButton(
        onPressed: () => showShareCardDialog(context, widget.storageService),
        icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
        tooltip: '今日の記録を共有',
      ),
    );
  }

  /// セリフのトーン（_getPontaMessageの段階分け）と表情を揃える
  PontaExpression _getPontaExpression() {
    final ratio = _todayCalories / _calorieGoal;
    if (_todayCalories == 0) return PontaExpression.smug; // 辛口の催促
    if (ratio <= 0.5) return PontaExpression.wink; // ドヤ褒め
    if (ratio < 0.8) return PontaExpression.normal;
    if (ratio <= 1.0) return PontaExpression.panic; // ギリギリは汗だくで焦る
    return PontaExpression.angry; // オーバーは怒り
  }

  Widget _buildPontaCard() {
    final isMacho = _isMacho();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // 頑張りが続いているときだけムキムキ化（減量継続 or 目標内5日連続）
          if (isMacho)
            const MachoPonta(size: 80)
          else
            PontaPuppet(size: 76, expression: _getPontaExpression()),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isMacho ? _getMachoMessage() : _getPontaMessage(),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(double progress, int remaining) {
    return AppCard(
        child: Column(
          children: [
            const SectionTitle('今日のカロリー'),
            const SizedBox(height: 20),
            CalorieRing(
              progress: progress,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_todayCalories',
                    style: GoogleFonts.nunito(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: progress > 1.0
                          ? AppTheme.danger
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '/ $_calorieGoal kcal',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (remaining >= 0 ? AppTheme.success : AppTheme.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                remaining >= 0
                    ? 'あと $remaining kcal 食べられる'
                    : '$_calorieGoal kcal を ${-remaining} kcal オーバー',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: remaining >= 0
                      ? const Color(0xFF2E7D32)
                      : AppTheme.danger,
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildMealSummary() {
    final goals = {
      'breakfast': widget.storageService.getBreakfastGoal(),
      'lunch': widget.storageService.getLunchGoal(),
      'dinner': widget.storageService.getDinnerGoal(),
      'snack': widget.storageService.getSnackGoal(),
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('食事の内訳'),
          const SizedBox(height: 8),
          for (final entry in goals.entries)
            MealProgressRow(
              type: entry.key,
              calories: _todayEntries
                  .where((e) => e.type == entry.key)
                  .fold(0, (sum, e) => sum + e.calories),
              goal: entry.value,
            ),
        ],
      ),
    );
  }
}
