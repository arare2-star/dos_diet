import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/sfx_service.dart';

/// 🦝 パーツ分け素材を組み立てて動かすぽんぽこ人形。
/// 素材は assets/images/ponta_parts/（ChatGPT生成画像を tools/extract_parts.py で
/// 背景抜き＋切り出ししたもの）。しっぽ・頭・手が常時ゆるく動き、タップでぴょん＋「ぽんっ」
class PontaPuppet extends StatefulWidget {
  /// 表示高さ。幅はデザイン比率(560:660)から自動で決まる
  final double size;

  const PontaPuppet({super.key, this.size = 96});

  @override
  State<PontaPuppet> createState() => _PontaPuppetState();
}

class _PontaPuppetState extends State<PontaPuppet>
    with SingleTickerProviderStateMixin {
  // デザイン座標系（Python合成プレビューと同じ数値）
  static const _designW = 560.0;
  static const _designH = 660.0;

  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;

  double _jumpT = 1.0; // 1.0=ジャンプしていない
  double _excite = 0; // タップ直後はしっぽが速く振れる

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;
    if (_jumpT < 1.0) _jumpT = min(1.0, _jumpT + dt * 2.2);
    if (_excite > 0) _excite = max(0.0, _excite - dt);
    if (mounted) setState(() {});
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    Sfx.play('pon');
    setState(() {
      _jumpT = 0;
      _excite = 1.2;
    });
  }

  Widget _part(
    String name, {
    required double left,
    required double top,
    required double width,
    double angle = 0,
    Alignment pivot = Alignment.center,
  }) {
    final s = widget.size / _designH;
    final child = Image.asset(
      'assets/images/ponta_parts/$name.png',
      width: width * s,
      filterQuality: FilterQuality.medium,
    );
    return Positioned(
      left: left * s,
      top: top * s,
      child: angle == 0
          ? child
          : Transform.rotate(angle: angle, alignment: pivot, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ゆるいアイドルモーション（それぞれ周期をずらして機械っぽさを消す）
    final wagSpeed = 1 + _excite * 3;
    final tailA = sin(_t * 2 * pi / 1.6 * wagSpeed) * (0.08 + _excite * 0.10);
    final headA = sin(_t * 2 * pi / 3.1) * 0.035;
    final armA = sin(_t * 2 * pi / 2.3) * 0.05;
    final breathe = sin(_t * 2 * pi / 2.0) * 1.6; // 全体のふわふわ(px)
    final jumpY = _jumpT < 1.0 ? -sin(pi * _jumpT) * widget.size * 0.12 : 0.0;

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: widget.size * _designW / _designH,
        height: widget.size,
        child: Transform.translate(
          offset: Offset(0, jumpY + breathe * widget.size / _designH),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 後ろ→前の順
              _part('tail',
                  left: 330, top: 300, width: 304,
                  angle: tailA, pivot: const Alignment(-0.8, 0.9)),
              _part('body', left: 91, top: 350, width: 378),
              _part('foot_l', left: 150, top: 528, width: 143),
              _part('foot_r', left: 272, top: 528, width: 137),
              _part('arm_l',
                  left: 96, top: 420, width: 169,
                  angle: armA, pivot: const Alignment(0.8, 0.8)),
              _part('arm_r',
                  left: 302, top: 420, width: 152,
                  angle: -armA, pivot: const Alignment(-0.8, 0.8)),
              _part('head',
                  left: 77, top: 30, width: 407,
                  angle: headA, pivot: const Alignment(0, 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}
