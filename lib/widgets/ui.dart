import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// 食事タイプごとの表示メタ情報（アイコン・色・ラベル）
class MealMeta {
  final String label;
  final IconData icon;
  final Color color;

  const MealMeta(this.label, this.icon, this.color);

  static const Map<String, MealMeta> byType = {
    'breakfast': MealMeta('朝食', Icons.wb_twilight_rounded, Color(0xFFFFA726)),
    'lunch': MealMeta('昼食', Icons.wb_sunny_rounded, Color(0xFFFF7043)),
    'dinner': MealMeta('夕食', Icons.nightlight_round, Color(0xFF9575CD)),
    'snack': MealMeta('おやつ', Icons.cookie_rounded, Color(0xFFF06292)),
  };

  static MealMeta of(String type) =>
      byType[type] ?? const MealMeta('食事', Icons.restaurant_rounded, AppTheme.primary);
}

/// 丸い色付き背景つきの食事アイコン
class MealIcon extends StatelessWidget {
  final String type;
  final double size;

  const MealIcon({super.key, required this.type, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final meta = MealMeta.of(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(meta.icon, color: meta.color, size: size * 0.52),
    );
  }
}

/// 画面上部のグラデーションヘッダー（装飾円つき）。全タブで共通の見た目にする
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle; // タイトルの上に小さく出す（日付など）
  final double bottomPadding;
  final Widget? trailing; // 右端のアクション（共有ボタンなど）

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.bottomPadding = 24,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, 60, 24, bottomPadding),
        decoration: BoxDecoration(gradient: AppTheme.headerGradient),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(top: -70, right: -50, child: _circle(180)),
            Positioned(top: 30, right: 60, child: _circle(70)),
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null) ...[
                          Text(
                            subtitle!,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          title,
                          style: GoogleFonts.nunito(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }
}

/// アプリ共通のカード。淡いボーダー＋柔らかい影で統一する
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

/// カード内の小見出し
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

/// カロリーの進捗リング。角丸キャップ＋グラデーションのカスタム描画で、
/// 値の変化はアニメーションする
class CalorieRing extends StatelessWidget {
  final double progress; // 0.0〜（1.0超はオーバー）
  final Widget center;
  final double size;
  final double strokeWidth;

  const CalorieRing({
    super.key,
    required this.progress,
    required this.center,
    this.size = 180,
    this.strokeWidth = 14,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: value,
                strokeWidth: strokeWidth,
                over: value > 1.0,
              ),
            ),
            center,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final bool over;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.over,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppTheme.primary.withValues(alpha: 0.10);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    const start = -pi / 2;
    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    final colors = over
        ? const [Color(0xFFEF5350), Color(0xFFE64A19)]
        : const [AppTheme.secondary, AppTheme.primary];

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + max(sweep, 0.1),
        colors: colors,
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);

    // 先端に白い点を打って「針」の位置を示す
    final tipAngle = start + sweep;
    final tip = Offset(
      center.dx + radius * cos(tipAngle),
      center.dy + radius * sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      strokeWidth * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.over != over;
}

/// 🔥 連続記録日数（ストリーク）と今週の記録状況
class StreakBar extends StatelessWidget {
  final int streak;
  final List<bool> weekRecorded; // 月〜日
  final bool recordedToday;

  const StreakBar({
    super.key,
    required this.streak,
    required this.weekRecorded,
    required this.recordedToday,
  });

  static const _fire = Color(0xFFFF6D00);
  static const _dayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;
    // 今日未記録でストリークが懸かっているときは煽る
    final atRisk = streak >= 2 && !recordedToday;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _fire.withValues(alpha: streak > 0 ? 0.14 : 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: streak > 0
                  ? _fire
                  : AppTheme.textSecondary.withValues(alpha: 0.4),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '$streak日連続記録中！' : '今日から連続記録スタート',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (atRisk)
                  Text(
                    '今日サボると消滅するぽん…！',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _fire,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: weekRecorded[i]
                              ? _fire
                              : _fire.withValues(alpha: 0.12),
                          border: i == todayIndex
                              ? Border.all(color: _fire, width: 1.5)
                              : null,
                        ),
                        child: weekRecorded[i]
                            ? const Icon(Icons.check,
                                size: 10, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dayLabels[i],
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          fontWeight: i == todayIndex
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: i == todayIndex
                              ? _fire
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ラベル＋実績/目標＋プログレスバーの1行（食事の内訳などで使用）
class MealProgressRow extends StatelessWidget {
  final String type;
  final int calories;
  final int goal;

  const MealProgressRow({
    super.key,
    required this.type,
    required this.calories,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final meta = MealMeta.of(type);
    final ratio = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = goal > 0 && calories > goal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          MealIcon(type: type, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      meta.label,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: '$calories',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isOver ? AppTheme.danger : AppTheme.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: ' / $goal kcal',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: meta.color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(
                        isOver ? AppTheme.danger : meta.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
