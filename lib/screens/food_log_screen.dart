import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/openai_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';
import '../models/food_entry.dart';
import '../theme.dart';

class FoodLogScreen extends StatefulWidget {
  final StorageService storageService;
  final SubscriptionService subscriptionService;

  const FoodLogScreen({
    super.key,
    required this.storageService,
    required this.subscriptionService,
  });

  @override
  State<FoodLogScreen> createState() => FoodLogScreenState();
}

class FoodLogScreenState extends State<FoodLogScreen> {
  late DateTime _selectedDate;
  late List<FoodEntry> _entries;
  final ImagePicker _picker = ImagePicker();

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

  /// 📸 画像からカロリーを推定してダイアログを表示
  Future<void> _scanFoodImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (image == null || !mounted) return;

    // ローディングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'ぽんぽこコーチが分析中だぽん... 🐾',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await OpenAIService.estimateCaloriesFromImage(
        File(image.path),
      );

      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる

      // フィードバックはダイアログ内で食事タイプ選択と連動して計算するため、
      // ここでは result と image.path だけ渡す
      _showScanResultDialog(result, image.path);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  /// スキャン結果ダイアログ（食事タイプ選択でフィードバックがリアルタイム更新）
  void _showScanResultDialog(CalorieResult result, String imagePath) {
    String selectedType = 'lunch';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 食事タイプが変わるたびにフィードバックを再計算
          final mealGoal = widget.storageService.getMealGoal(selectedType);
          final feedback = OpenAIService.getPontaFeedback(
            result.calories,
            mealGoal,
            selectedType,
          );
          // カロリーバーの色：目標オーバーなら警告色
          final ratio = result.calories / mealGoal;
          final calColor = ratio > 1.0 ? AppTheme.danger : AppTheme.primary;

          return AlertDialog(
            backgroundColor: AppTheme.background,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              'スキャン結果 📸',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 画像プレビュー
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      height: 150,
                      width: 280,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 食べ物名
                  Text(
                    result.foodName,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // カロリー（目標比で色が変わる）
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: calColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${result.calories} kcal',
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: calColor,
                          ),
                        ),
                        Text(
                          '目標 $mealGoal kcal',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ぽんぽこコーチフィードバック（食事タイプ連動）
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          feedback.imagePath,
                          width: 64,
                          height: 64,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feedback.message,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 食事タイプ選択（タップでフィードバック即更新）
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
              ElevatedButton.icon(
                onPressed: () async {
                  final entry = FoodEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: result.foodName,
                    calories: result.calories,
                    type: selectedType,
                    dateTime: _selectedDate,
                  );
                  await widget.storageService.addFoodEntry(entry);
                  refresh();
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('記録する'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddFoodDialog() async {
    // サブスク確認（手動入力もカロリー記録機能のため有料）
    final canUse = await _checkSubscriptionAndProceed();
    if (!canUse || !mounted) return;

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

  /// 💎 サブスク状態を確認してから処理を実行
  Future<bool> _checkSubscriptionAndProceed() async {
    final sub = widget.subscriptionService;
    if (sub.canUseCalorieAnalysis) {
      // トライアル中はバナーを表示
      if (sub.status == SubscriptionStatus.trial) {
        final daysLeft = sub.trialDaysRemaining;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'トライアル残り$daysLeft日だぽん！🐾',
                style: GoogleFonts.nunito(),
              ),
              backgroundColor: AppTheme.secondary,
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'プランを見る',
                textColor: Colors.white,
                onPressed: () => _showPaywall(),
              ),
            ),
          );
        }
      }
      return true;
    }

    // トライアル期限切れ → ペイウォールを表示
    await _showPaywall();
    return widget.subscriptionService.canUseCalorieAnalysis;
  }

  /// 💳 ペイウォール画面を開く
  Future<void> _showPaywall() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          subscriptionService: widget.subscriptionService,
        ),
      ),
    );
    if (mounted) setState(() {}); // 購入後にUIを更新
  }

  /// 📸 カメラ or ギャラリー選択シート（サブスク確認付き）
  Future<void> _showImageSourceSheet() async {
    // まずサブスク状態を確認
    final canUse = await _checkSubscriptionAndProceed();
    if (!canUse || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '食べ物をスキャン 📸',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ぽんぽこコーチがカロリーを推定するぽん！',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: Text(
                  'カメラで撮影',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _scanFoodImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.secondary,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: Text(
                  'ライブラリから選択',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _scanFoodImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
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
    final totalCalories = _entries.fold(0, (sum, e) => sum + e.calories);

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
              Row(
                children: [
                  // 📸 スキャンボタン
                  IconButton(
                    onPressed: _showImageSourceSheet,
                    icon: const Icon(Icons.camera_alt, color: AppTheme.primary),
                    tooltip: '写真でスキャン',
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
                        'まだ記録がないぽん！\n食事を追加するぽん',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showImageSourceSheet,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: Text(
                          '写真でスキャン 📸',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _showAddFoodDialog,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(
                          '手動で追加',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
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
