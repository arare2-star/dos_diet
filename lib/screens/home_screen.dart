import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/food_entry.dart';
import '../theme.dart';

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

  String _getPontaMessage() {
    final ratio = _todayCalories / _calorieGoal;
    if (_todayCalories == 0) {
      return 'さっさと記録するぽん。始めないと意味ないぽん。';
    } else if (ratio <= 0.5) {
      return 'おっ、やるじゃないかぽん！その調子で続けるぽん！';
    } else if (ratio < 0.8) {
      return 'まあ悪くはないぽん。油断すんなよぽん。';
    } else if (ratio < 1.0) {
      return 'ギリギリだぽん。あと少し、踏ん張るぽん。';
    } else if (ratio < 1.2) {
      return 'オーバーしてるじゃないかぽん。反省するぽん。';
    } else {
      return 'はあ？食いすぎだぽん。明日からやり直すぽん。';
    }
  }

  String _getPontaImage() {
    final ratio = _todayCalories / _calorieGoal;
    if (_todayCalories == 0 || ratio <= 0.5) {
      return 'assets/images/ponta_happy.png';
    } else if (ratio < 1.0) {
      return 'assets/images/ponta_default.png';
    } else if (ratio < 1.3) {
      return 'assets/images/ponta_shocked.png';
    } else {
      return 'assets/images/ponta_angry.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_todayCalories / _calorieGoal).clamp(0.0, 1.5);
    final remaining = _calorieGoal - _todayCalories;
    final dateStr = DateFormat('M月d日（E）', 'ja').format(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(dateStr),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildPontaCard(),
                const SizedBox(height: 20),
                _buildCalorieCard(progress, remaining),
                const SizedBox(height: 20),
                _buildMealSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String dateStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ぽんぽこ',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPontaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(_getPontaImage(), width: 64, height: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getPontaMessage(),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(double progress, int remaining) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '今日のカロリー',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 12,
                    backgroundColor: AppTheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 1.0 ? AppTheme.danger : AppTheme.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_todayCalories',
                      style: GoogleFonts.nunito(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: progress > 1.0
                            ? AppTheme.danger
                            : AppTheme.primary,
                      ),
                    ),
                    Text(
                      '/ $_calorieGoal kcal',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            remaining >= 0 ? '残り $remaining kcal' : '${-remaining} kcal オーバー',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: remaining >= 0 ? AppTheme.success : AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSummary() {
    final mealTypes = {
      'breakfast': '朝食 🌅',
      'lunch': '昼食 ☀️',
      'dinner': '夕食 🌙',
      'snack': 'おやつ 🍪',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '食事の内訳',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...mealTypes.entries.map((entry) {
            final mealCalories = _todayEntries
                .where((e) => e.type == entry.key)
                .fold(0, (sum, e) => sum + e.calories);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.value,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '$mealCalories kcal',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
