import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

// TODO: HTMLをホスティング後、実際のURLに置き換えてください
const String _privacyPolicyUrl = 'https://YOUR_DOMAIN/privacy_policy.html';
const String _termsOfUseUrl = 'https://YOUR_DOMAIN/terms_of_use.html';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;

  const SettingsScreen({super.key, required this.storageService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _calorieGoal;
  late bool _notificationsEnabled;
  late int _notificationHour;
  late int _notificationMinute;

  @override
  void initState() {
    super.initState();
    _calorieGoal = widget.storageService.getCalorieGoal();
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  '目標設定',
                  Icons.track_changes,
                  [_buildCalorieGoalTile()],
                ),
                const SizedBox(height: 20),
                _buildSection(
                  'ぽんたコーチ通知 🐾',
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
          '設定',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
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

  Widget _buildCalorieGoalTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        'カロリー目標',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        '$_calorieGoal kcal / 日',
        style: GoogleFonts.nunito(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: _showCalorieGoalDialog,
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
        }
      },
    );
  }

  Widget _buildNotificationTimeTile() {
    final timeStr =
        '${_notificationHour.toString().padLeft(2, '0')}:${_notificationMinute.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        '通知時間',
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        timeStr,
        style: GoogleFonts.nunito(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: _notificationHour,
            minute: _notificationMinute,
          ),
        );
        if (time != null) {
          setState(() {
            _notificationHour = time.hour;
            _notificationMinute = time.minute;
          });
          await widget.storageService.setNotificationTime(
            time.hour,
            time.minute,
          );
        }
      },
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
                'ぽんたコーチから通知を送ったよ！ 🐾',
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

  void _showCalorieGoalDialog() {
    final controller = TextEditingController(text: _calorieGoal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'カロリー目標',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '1日の目標摂取カロリーを設定',
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
              children: [1500, 1800, 2000, 2500].map((value) {
                return ActionChip(
                  label: Text(
                    '$value',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  backgroundColor: AppTheme.surface,
                  onPressed: () {
                    controller.text = value.toString();
                  },
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
                setState(() => _calorieGoal = value);
                await widget.storageService.setCalorieGoal(value);
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
