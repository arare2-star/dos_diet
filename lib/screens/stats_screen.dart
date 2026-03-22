import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../models/weight_entry.dart';
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
  late List<WeightEntry> _weeklyWeights;
  late List<DateTime> _weekDates;

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
    _weekDates = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final calories = widget.storageService.getTotalCaloriesForDate(date);
      _weeklyCalories.add(calories);
      _weekDayLabels.add(DateFormat('E', 'ja').format(date));
      _weekDates.add(date);
    }

    final total = _weeklyCalories.fold(0, (sum, c) => sum + c);
    _weeklyAverage = _weeklyCalories.isNotEmpty ? total ~/ 7 : 0;

    final rangeStart = now.subtract(const Duration(days: 6));
    _weeklyWeights = widget.storageService.getWeightEntriesForRange(
      DateTime(rangeStart.year, rangeStart.month, rangeStart.day),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    setState(() {});
  }

  void _showWeightInputDialog([DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();
    final existing = widget.storageService.getWeightForDate(date);
    final controller = TextEditingController(
      text: existing != null ? existing.weight.toString() : '',
    );
    final dateStr = DateFormat('M月d日（E）', 'ja').format(date);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$dateStr の体重',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            hintText: '例: 65.0',
            suffixText: 'kg',
            hintStyle: GoogleFonts.nunito(color: AppTheme.textSecondary),
            suffixStyle: GoogleFonts.nunito(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'キャンセル',
              style: GoogleFonts.nunito(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                final entry = WeightEntry(
                  id: '${date.year}${date.month}${date.day}',
                  weight: val,
                  dateTime: DateTime(date.year, date.month, date.day, 12),
                );
                await widget.storageService.addOrUpdateWeightEntry(entry);
                if (ctx.mounted) Navigator.pop(ctx);
                refresh();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '保存',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
                const SizedBox(height: 20),
                _buildWeightSection(),
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
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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

  Widget _buildWeightSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '体重推移',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _showWeightInputDialog(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '記録',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _weeklyWeights.length < 2
              ? _buildWeightEmptyState()
              : _buildWeightChart(),
          const SizedBox(height: 16),
          _buildWeightDayList(),
        ],
      ),
    );
  }

  Widget _buildWeightEmptyState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart,
              size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            '2日以上記録するとグラフが表示されます',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    final weights = _weeklyWeights.map((e) => e.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1.0;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1.0;

    // 7日間の各日にデータがあれば使い、なければnullのスポット
    final spots = <FlSpot>[];
    for (int i = 0; i < _weekDates.length; i++) {
      final date = _weekDates[i];
      final entry = _weeklyWeights.cast<WeightEntry?>().firstWhere(
            (e) =>
                e != null &&
                e.dateTime.year == date.year &&
                e.dateTime.month == date.month &&
                e.dateTime.day == date.day,
            orElse: () => null,
          );
      if (entry != null) {
        spots.add(FlSpot(i.toDouble(), entry.weight));
      }
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minW,
          maxY: maxW,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} kg',
                    GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(1)}',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.surface,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.accent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: AppTheme.accent,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.accent.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightDayList() {
    return Column(
      children: List.generate(_weekDates.length, (i) {
        final date = _weekDates[i];
        final isToday = i == 6;
        final entry = _weeklyWeights.cast<WeightEntry?>().firstWhere(
              (e) =>
                  e != null &&
                  e.dateTime.year == date.year &&
                  e.dateTime.month == date.month &&
                  e.dateTime.day == date.day,
              orElse: () => null,
            );
        final dateStr = DateFormat('M/d（E）', 'ja').format(date);

        return GestureDetector(
          onTap: () => _showWeightInputDialog(date),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                entry != null
                    ? Text(
                        '${entry.weight.toStringAsFixed(1)} kg',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : Text(
                        'タップして記録',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
