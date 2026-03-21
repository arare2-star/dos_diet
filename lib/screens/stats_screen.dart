import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class StatsScreen extends StatefulWidget {
  final StorageService storageService;

  const StatsScreen({super.key, required this.storageService});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  late List<int> _weeklyCalories;
  late List<String> _weekDayLabels;
  late int _weeklyAverage;
  late int _calorieGoal;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final now = DateTime.now();
    _calorieGoal = widget.storageService.getCalorieGoal();
    _weeklyCalories = [];
    _weekDayLabels = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final calories = widget.storageService.getTotalCaloriesForDate(date);
      _weeklyCalories.add(calories);
      _weekDayLabels.add(DateFormat('E', 'ja').format(date));
    }

    final total = _weeklyCalories.fold(0, (sum, c) => sum + c);
    _weeklyAverage = _weeklyCalories.isNotEmpty ? total ~/ 7 : 0;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildWeeklySummary(),
                const SizedBox(height: 20),
                _buildWeeklyChart(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        child: Text(
          '統計',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySummary() {
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
            '週間サマリー',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('1日平均', '$_weeklyAverage kcal'),
              _buildStatItem('目標', '$_calorieGoal kcal'),
              _buildStatItem(
                '達成率',
                _calorieGoal > 0
                    ? '${((_weeklyAverage / _calorieGoal) * 100).toInt()}%'
                    : '0%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final maxCalories = _weeklyCalories.isEmpty
        ? _calorieGoal.toDouble()
        : [
            ..._weeklyCalories.map((c) => c.toDouble()),
            _calorieGoal.toDouble()
          ].reduce((a, b) => a > b ? a : b);

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
            '週間カロリー推移',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCalories * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _weekDayLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _weekDayLabels[index],
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyCalories.asMap().entries.map((entry) {
                  final isToday = entry.key == 6;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        color: isToday ? AppTheme.accent : AppTheme.primary,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: _calorieGoal.toDouble(),
                      color: AppTheme.danger.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
