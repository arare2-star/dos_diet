import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/food_entry.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// 月記録タブ: 1か月をカレンダー形式で振り返る。
/// 日ごとの合計kcalと目標内/オーバーを色で示し、タップでその日の食事一覧を出す
class MonthlyScreen extends StatefulWidget {
  final StorageService storageService;

  const MonthlyScreen({super.key, required this.storageService});

  @override
  State<MonthlyScreen> createState() => MonthlyScreenState();
}

class MonthlyScreenState extends State<MonthlyScreen> {
  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  late DateTime _month; // 表示中の月（1日固定）
  DateTime? _selectedDay;
  late int _calorieGoal;
  late Map<int, int> _dayTotals; // 日 → 合計kcal（記録がある日だけ）
  late Map<int, double> _dayWeights; // 日 → 体重（記録がある日だけ）

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    refresh();
  }

  void refresh() {
    _calorieGoal = widget.storageService.getCalorieGoal();
    _dayTotals = {};
    _dayWeights = {};
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    for (var d = 1; d <= days; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final total = widget.storageService.getTotalCaloriesForDate(date);
      if (total > 0) _dayTotals[d] = total;
      final w = widget.storageService.getWeightForDate(date);
      if (w != null) _dayWeights[d] = w.weight;
    }
    setState(() {});
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return; // 未来の月は出さない
    _month = next;
    _selectedDay = null;
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const GradientHeader(title: '月記録'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              children: [
                _buildMonthNav(),
                const SizedBox(height: 16),
                _buildSummary(),
                const SizedBox(height: 20),
                _buildCalendar(),
                if (_selectedDay != null) ...[
                  const SizedBox(height: 20),
                  _buildDayDetail(_selectedDay!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
        ),
        Text(
          DateFormat('yyyy年M月').format(_month),
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        IconButton(
          onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
          icon: Icon(
            Icons.chevron_right,
            color: _isCurrentMonth
                ? AppTheme.textSecondary.withValues(alpha: 0.3)
                : AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final recorded = _dayTotals.length;
    final within = _dayTotals.values.where((c) => c <= _calorieGoal).length;
    final average = recorded == 0
        ? 0
        : _dayTotals.values.fold(0, (s, c) => s + c) ~/ recorded;

    return AppCard(
      child: Column(
        children: [
          Text(
            '月間サマリー',
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
              _statItem('記録した日', '$recorded日'),
              _statItem('目標内の日', '$within日'),
              _statItem('1日平均', '$average kcal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
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

  Widget _buildCalendar() {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = _month.weekday - 1; // 月曜始まり。1日の前に入れる空セル数
    final today = DateUtils.dateOnly(DateTime.now());

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++)
        _buildDayCell(DateTime(_month.year, _month.month, d), today),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        children: [
          Row(
            children: _weekdayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            // 指定しないとセーフエリア分の余白が上下に自動で入ってしまう
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.9,
            children: cells,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppTheme.success, '目標内'),
              const SizedBox(width: 16),
              _legend(AppTheme.danger, 'オーバー'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final total = _dayTotals[date.day];
    final weight = _dayWeights[date.day];
    final isFuture = date.isAfter(today);
    final isToday = DateUtils.isSameDay(date, today);
    final isSelected =
        _selectedDay != null && DateUtils.isSameDay(date, _selectedDay);

    Color? fill;
    if (total != null) {
      fill = (total <= _calorieGoal ? AppTheme.success : AppTheme.danger)
          .withValues(alpha: 0.18);
    }

    return GestureDetector(
      onTap: isFuture ? null : () => setState(() => _selectedDay = date),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : isToday
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : Colors.transparent,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isFuture
                    ? AppTheme.textSecondary.withValues(alpha: 0.3)
                    : AppTheme.textPrimary,
              ),
            ),
            if (total != null)
              Text(
                '$total',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            if (weight != null)
              Text(
                '${weight.toStringAsFixed(1)}kg',
                style: GoogleFonts.nunito(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetail(DateTime date) {
    final entries = widget.storageService.getFoodEntriesForDate(date)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final total = entries.fold(0, (s, e) => s + e.calories);
    final weight = widget.storageService.getWeightForDate(date);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('M月d日（E）', 'ja').format(date),
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (entries.isNotEmpty)
                Text(
                  '$total kcal',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: total <= _calorieGoal
                        ? AppTheme.success
                        : AppTheme.danger,
                  ),
                ),
            ],
          ),
          if (weight != null) ...[
            const SizedBox(height: 4),
            Text(
              '体重 ${weight.weight.toStringAsFixed(1)} kg',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'この日は記録がないぽん',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            )
          else
            ...entries.map(_buildEntryRow),
        ],
      ),
    );
  }

  Widget _buildEntryRow(FoodEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MealIcon(type: entry.type, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            '${entry.calories} kcal',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
