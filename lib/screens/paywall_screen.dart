import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../widgets/ponta_puppet.dart';

class PaywallScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  const PaywallScreen({super.key, required this.subscriptionService});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;

  Future<void> _purchase(ProductDetails product) async {
    setState(() => _isLoading = true);
    try {
      final success = await widget.subscriptionService.purchase(product);
      if (!success && mounted) {
        _showSnack('購入を開始できなかったぽん。もう一度試すぽん 🐾');
      }
    } catch (e) {
      if (mounted) _showSnack('エラーが発生したぽん: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      await widget.subscriptionService.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        if (widget.subscriptionService.subscriptionActive) {
          _showSnack('購入を復元したぽん！ 🎉');
          Navigator.pop(context, true);
        } else {
          _showSnack('復元できる購入が見つからなかったぽん');
        }
      }
    } catch (e) {
      if (mounted) _showSnack('復元に失敗したぽん: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.nunito()),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscriptionService;
    final daysLeft = sub.trialDaysRemaining;
    final isExpired = sub.status == SubscriptionStatus.expired;
    final monthly = sub.monthlyProduct;
    final annual = sub.annualProduct;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 閉じるボタン
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 8),

              // うるうる両手で「お願い、課金して」
              const PontaPuppet(size: 110, expression: PontaExpression.plead),
              const SizedBox(height: 16),

              // タイトル
              Text(
                isExpired ? 'トライアル終了だぽん 😤' : 'あと${daysLeft}日で終わるぽん！',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isExpired
                    ? 'AI写真スキャン機能を使い続けるには\nプレミアムプランが必要だぽん'
                    : '今のうちに登録しておくぽん！\nトライアル終了後も使い続けられるぽん',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // 機能一覧
              _buildFeatureCard(),
              const SizedBox(height: 28),

              // 月額ボタン
              if (monthly != null)
                _buildPlanButton(
                  label: '月額プラン',
                  price: '${monthly.price}/月',
                  onTap: () => _purchase(monthly),
                ),
              if (monthly != null) const SizedBox(height: 12),

              // 年額ボタン
              if (annual != null)
                _buildPlanButton(
                  label: '年額プラン（お得！）',
                  price: '${annual.price}/年',
                  onTap: () => _purchase(annual),
                  isHighlight: true,
                ),

              // 商品未取得時
              if (monthly == null && annual == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      '読み込み中だぽん...',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // 復元ボタン
              TextButton(
                onPressed: _isLoading ? null : _restore,
                child: Text(
                  '以前の購入を復元するぽん',
                  style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 8),

              // 注意書き
              Text(
                'サブスクリプションはiTunes Storeアカウントに請求されます。\n購入後は自動更新されます。いつでもキャンセル可能です。',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanButton({
    required String label,
    required String price,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isHighlight ? AppTheme.primary : AppTheme.surface,
          foregroundColor: isHighlight ? Colors.white : AppTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isHighlight
                ? BorderSide.none
                : BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          elevation: isHighlight ? 2 : 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  color: isHighlight ? Colors.white : AppTheme.primary,
                  strokeWidth: 2,
                ),
              )
            : Column(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isHighlight ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    price,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: isHighlight
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFeatureCard() {
    const features = [
      (Icons.camera_alt_rounded, Color(0xFFFF7043), 'AI写真スキャン', '食べ物を撮るだけでカロリーを自動推定'),
      (Icons.pets_rounded, Color(0xFF8D6E63), 'ぽんぽこコーチ', '辛口コーチが毎日サポートしてくれるぽん'),
      (Icons.insights_rounded, Color(0xFF9575CD), '詳細統計', '食事の傾向をグラフで確認'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: f.$2.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(f.$1, color: f.$2, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$3, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text(f.$4, style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
