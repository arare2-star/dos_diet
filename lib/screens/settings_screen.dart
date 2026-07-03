import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';
import '../theme.dart';
import '../widgets/ui.dart';

const String _privacyPolicyUrl = 'https://arare2-star.github.io/dos_diet/privacy_policy.html';
const String _termsOfUseUrl = 'https://arare2-star.github.io/dos_diet/terms_of_use.html';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final SubscriptionService subscriptionService;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.subscriptionService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 食事別カロリー目標
  late int _breakfastGoal;
  late int _lunchGoal;
  late int _dinnerGoal;
  late int _snackGoal;

  late bool _notificationsEnabled;
  late int _notificationHour;
  late int _notificationMinute;

  @override
  void initState() {
    super.initState();
    _breakfastGoal = widget.storageService.getBreakfastGoal();
    _lunchGoal     = widget.storageService.getLunchGoal();
    _dinnerGoal    = widget.storageService.getDinnerGoal();
    _snackGoal     = widget.storageService.getSnackGoal();
    _notificationsEnabled = widget.storageService.getNotificationsEnabled();
    _notificationHour = widget.storageService.getNotificationHour();
    _notificationMinute = widget.storageService.getNotificationMinute();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💎 プレミアムセクション（最上部に配置）
                _buildPremiumSection(),
                const SizedBox(height: 20),
                _buildSection(
                  '食事別カロリー目標',
                  Icons.track_changes,
                  [
                    _buildMealGoalTile('breakfast', _breakfastGoal),
                    _buildMealGoalTile('lunch', _lunchGoal),
                    _buildMealGoalTile('dinner', _dinnerGoal),
                    _buildMealGoalTile('snack', _snackGoal),
                    _buildTotalCalorieTile(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSection(
                  'ぽんぽこコーチ通知',
                  Icons.notifications_active,
                  [
                    _buildNotificationToggle(),
                    if (_notificationsEnabled) _buildNotificationTimeTile(),
                    _buildTestNotificationTile(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '法的情報',
                  Icons.gavel,
                  [
                    _buildLinkTile(
                      'プライバシーポリシー',
                      Icons.privacy_tip_outlined,
                      _privacyPolicyUrl,
                    ),
                    _buildLinkTile(
                      '利用規約',
                      Icons.description_outlined,
                      _termsOfUseUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSection(
                  'アプリ情報',
                  Icons.info_outline,
                  [_buildAboutTile()],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const GradientHeader(title: '設定');
  }

  /// 💎 プレミアムセクション
  Widget _buildPremiumSection() {
    final sub = widget.subscriptionService;
    final status = sub.status;

    // 有効なサブスク
    if (status == SubscriptionStatus.active) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プレミアム会員',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'すべての機能が使えるぽん！🐾',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await sub.restorePurchases();
                if (mounted) setState(() {});
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: Text(
                '復元',
                style: GoogleFonts.nunito(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // トライアル中
    if (status == SubscriptionStatus.trial) {
      final daysLeft = sub.trialDaysRemaining;
      return GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaywallScreen(
                subscriptionService: widget.subscriptionService,
              ),
            ),
          );
          if (mounted) setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'トライアル中（残り$daysLeft日）',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'タップしてプレミアムにアップグレード',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      );
    }

    // トライアル期限切れ（未購入）
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaywallScreen(
              subscriptionService: widget.subscriptionService,
            ),
          ),
        );
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('💎', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プレミアムにアップグレード',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'AI写真スキャンを使うには月額¥390から',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: children
                .asMap()
                .entries
                .map((entry) {
                  final widget = entry.value;
                  final isLast = entry.key == children.length - 1;
                  return Column(
                    children: [
                      widget,
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppTheme.textSecondary.withValues(alpha: 0.1),
                        ),
                    ],
                  );
                })
                .toList(),
          ),
        ),
      ],
    );
  }

  /// 食事別カロリー目標タイル（各食事をタップで編集）
  Widget _buildMealGoalTile(String type, int currentGoal) {
    final label = MealMeta.of(type).label;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: MealIcon(type: type, size: 36),
      title: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        '$currentGoal kcal',
        style: GoogleFonts.nunito(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () => _showMealGoalDialog(type, label, currentGoal),
    );
  }

  /// 合計カロリー表示タイル（読み取り専用）
  Widget _buildTotalCalorieTile() {
    final total = _breakfastGoal + _lunchGoal + _dinnerGoal + _snackGoal;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        '1日合計',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
      trailing: Text(
        '$total kcal',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        '通知を有効にする',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      value: _notificationsEnabled,
      activeColor: AppTheme.primary,
      onChanged: (value) async {
        setState(() => _notificationsEnabled = value);
        await widget.storageService.setNotificationsEnabled(value);
        if (value) {
          await NotificationService.requestPermissions();
          await NotificationService.reschedule(widget.storageService);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '通知をオンにしたよ！8:00・12:00・19:00に届くぞ 🐾',
                  style: GoogleFonts.nunito(),
                ),
                backgroundColor: AppTheme.primary,
              ),
            );
          }
        } else {
          await NotificationService.cancelAllNotifications();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '通知をオフにしたよ 🐾',
                  style: GoogleFonts.nunito(),
                ),
                backgroundColor: AppTheme.textSecondary,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildNotificationTimeTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Text('🕐', style: TextStyle(fontSize: 20)),
      title: Text(
        '通知時間（固定）',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        '8:00（朝食）・12:00（昼食）・19:00（夕食）',
        style: GoogleFonts.nunito(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTestNotificationTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        'テスト通知を送る',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
      leading: const Padding(
        padding: EdgeInsets.only(left: 0),
        child: Text('🐾', style: TextStyle(fontSize: 20)),
      ),
      onTap: () async {
        await NotificationService.showPontaNotification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ぽんぽこコーチから通知を送ったよ！ 🐾',
                style: GoogleFonts.nunito(),
              ),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      },
    );
  }

  Widget _buildLinkTile(String title, IconData icon, String url) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppTheme.primary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.open_in_new, color: AppTheme.textSecondary, size: 18),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        'Dos Diet',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        'バージョン 1.0.0',
        style: GoogleFonts.nunito(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
      leading: const Icon(Icons.eco, color: AppTheme.primary),
    );
  }

  /// 食事別カロリー目標ダイアログ
  void _showMealGoalDialog(String type, String label, int currentGoal) {
    final controller = TextEditingController(text: currentGoal.toString());

    // 食事タイプ別のクイック選択値とヒントテキスト
    final Map<String, List<int>> quickValues = {
      'breakfast': [300, 400, 500, 600],
      'lunch':     [500, 600, 700, 800],
      'dinner':    [400, 500, 600, 700],
      'snack':     [100, 150, 200, 300],
    };
    final Map<String, String> hints = {
      'breakfast': '朝食はしっかり食べてOKぽん！',
      'lunch':     '昼食は1日の中心ぽん！',
      'dinner':    '夕食は控えめが理想ぽん！',
      'snack':     'おやつは少なめにするぽん！',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$label の目標',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hints[type] ?? 'カロリー目標を設定するぽん',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: 'kcal',
                suffixStyle: GoogleFonts.nunito(color: AppTheme.textSecondary),
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: (quickValues[type] ?? [300, 500, 700]).map((value) {
                return ActionChip(
                  label: Text(
                    '$value',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  backgroundColor: AppTheme.surface,
                  onPressed: () => controller.text = value.toString(),
                );
              }).toList(),
            ),
          ],
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
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                await widget.storageService.setMealGoal(type, value);
                // 今日の通知文面は目標カロリーを参照するので組み直す
                await NotificationService.reschedule(widget.storageService);
                setState(() {
                  switch (type) {
                    case 'breakfast': _breakfastGoal = value; break;
                    case 'lunch':     _lunchGoal     = value; break;
                    case 'dinner':    _dinnerGoal    = value; break;
                    case 'snack':     _snackGoal     = value; break;
                  }
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
