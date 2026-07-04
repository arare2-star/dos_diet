import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/storage_service.dart';
import '../theme.dart';
import 'ponta_puppet.dart';
import 'ui.dart';

/// 今日の記録をストーリーズ向け縦長カードにして共有するダイアログを開く
Future<void> showShareCardDialog(
  BuildContext context,
  StorageService storage,
) async {
  final boundaryKey = GlobalKey();

  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: boundaryKey,
            child: _DailyShareCard(storage: storage),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  '閉じる',
                  style: GoogleFonts.nunito(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _captureAndShare(boundaryKey),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('共有する'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _captureAndShare(GlobalKey boundaryKey) async {
  final boundary = boundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;

  // プレビューの4倍で書き出し（270x480 → 1080x1920）
  final image = await boundary.toImage(pixelRatio: 4.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;

  final file = File(
    '${Directory.systemTemp.path}/ponpoko_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(byteData.buffer.asUint8List());

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: '#ぽんぽこダイエット'),
  );
}

/// 9:16の共有カード本体
class _DailyShareCard extends StatelessWidget {
  final StorageService storage;

  const _DailyShareCard({required this.storage});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final total = storage.getTotalCaloriesForDate(today);
    final goal = storage.getCalorieGoal();
    final streak = storage.getStreakDays();
    final remaining = goal - total;
    final dateStr = DateFormat('yyyy.M.d（E）', 'ja').format(today);

    final mealCalories = {
      for (final type in MealMeta.byType.keys)
        type: storage
            .getFoodEntriesForDate(today)
            .where((e) => e.type == type)
            .fold(0, (sum, e) => sum + e.calories),
    };

    return Container(
      width: 270,
      height: 480,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(top: -60, right: -40, child: _circle(160)),
          Positioned(bottom: -50, left: -50, child: _circle(150)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '今日のぽんぽこ',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                // SNS用はドヤ顔で
                const PontaPuppet(size: 84, expression: PontaExpression.wink),
                const SizedBox(height: 10),
                // 合計カロリー
                Text.rich(
                  TextSpan(
                    text: '$total',
                    style: GoogleFonts.nunito(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(
                        text: ' / $goal kcal',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    remaining >= 0 ? '目標内クリア中✌️' : '${-remaining} kcal オーバー😇',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 食事内訳
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (final entry in mealCalories.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                MealMeta.of(entry.key).icon,
                                size: 14,
                                color: MealMeta.of(entry.key).color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                MealMeta.of(entry.key).label,
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${entry.value} kcal',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (streak > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$streak日連続記録中',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  '#ぽんぽこダイエット',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
      ),
    );
  }
}
