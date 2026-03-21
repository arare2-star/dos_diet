import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/food_entry.dart';
import '../theme.dart';

class FoodLogScreen extends StatefulWidget {
  final StorageService storageService;

  const FoodLogScreen({super.key, required this.storageService});

  @override
  State<FoodLogScreen> createState() => FoodLogScreenState();
}

class FoodLogScreenState extends State<FoodLogScreen> {
  late DateTime _selectedDate;
  late List<FoodEntry> _entries;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    refresh();
  }

  void refresh() {
    setState(() {
      _entries = widget.storageService.getFoodEntriesForDate(_selectedDate);
    });
  }

  void _showAddFoodDialog() {
    final nameController = TextEditingController();
    final calorieController = TextEditingController();
    String selectedType = 'breakfast';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '食事を追加',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '食品名',
                    hintText: '例: ごはん、サラダ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: calorieController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'カロリー (kcal)',
                    hintText: '例: 300',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    _mealChip('breakfast', '朝食 🌅', selectedType,
                        (val) => setDialogState(() => selectedType = val)),
                    _mealChip('lunch', '昼食 ☀️', selectedType,
                        (val) => setDialogState(() => selectedType = val)),
                    _mealChip('dinner', '夕食 🌙', selectedType,
                        (val) => setDialogState(() => selectedType = val)),
                    _mealChip('snack', 'おやつ 🍪', selectedType,
                        (val) => setDialogState(() => selectedType = val)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'キャンセル',
                style: GoogleFonts.nunito(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final calories = int.tryParse(calorieController.text);
                if (name.isNotEmpty && calories != null && calories > 0) {
                  final entry = FoodEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    calories: calories,
                    type: selectedType,
                    dateTime: _selectedDate,
                  );
                  await widget.storageService.addFoodEntry(entry);
                  refresh();
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealChip(
      String value, String label, String selected, Function(String) onSelect) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onSelected: (_) => onSelect(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M月d日（E）', 'ja').format(_selectedDate);
    final totalCalories =
        _entries.fold(0, (sum, e) => sum + e.calories);

    return Column(
      children: [
        _buildHeader(),
        _buildDateSelector(dateStr),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '合計: $totalCalories kcal',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddFoodDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  '追加',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🐾', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'まだ記録がないよ！\n食事を追加してね',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return _buildEntryCard(entry);
                  },
                ),
        ),
      ],
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
          '食事記録',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(String dateStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate =
                    _selectedDate.subtract(const Duration(days: 1));
              });
              refresh();
            },
            icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
          ),
          Text(
            dateStr,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              refresh();
            },
            icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(FoodEntry entry) {
    final mealIcons = {
      'breakfast': '🌅',
      'lunch': '☀️',
      'dinner': '🌙',
      'snack': '🍪',
    };

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await widget.storageService.removeFoodEntry(entry.id);
        refresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              mealIcons[entry.type] ?? '🍽️',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.calories} kcal',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
