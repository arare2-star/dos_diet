import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/sfx_service.dart';

/// ぽんぽこの表情。頭パーツの差し替えで実現。
/// 2026-07-18〜表情シート由来（tools/extract_faces.py、ponta_faces/）に統一
enum PontaExpression {
  normal, // 基本のにこにこ
  wink, // ウインク＋にやり（当たり・達成のドヤ顔）
  smug, // ジト目（辛口コーチ）
  shock, // 手を頭に＋汗（がーん）
  angry, // 怒り（怒りマーク＋鼻息）
  panic, // 焦る（汗だくだく）
  plead, // お願い（うるうる＋両手。※顔に手が含まれるので腕は非表示になる）
  sleepy, // 眠い（Zzz抜きの半目）
  cry, // 泣く（大粒の涙）
  surprised, // 驚き（目まんまる＋フラッシュ）
}

/// 頭の横に浮かぶエフェクト（マッチョ仕様書シートのエフェクトパーツ由来）
enum PontaEffect {
  sweat, // 汗（焦り）
  fire, // 燃えてる（炎上・オーバー）
  heart, // ハート（ご機嫌・お願い）
  meat, // 肉
  beer, // ビール
  rice, // ご飯（記録の催促）
}

/// 🦝 パーツ分け素材を組み立てて動かすぽんぽこ人形。
/// 素材は assets/images/ponta_parts/（ChatGPT生成画像を tools/extract_parts.py で
/// 背景抜き＋切り出ししたもの）。しっぽ・頭・手が常時ゆるく動き、タップでぴょん＋「ぽんっ」
class PontaPuppet extends StatefulWidget {
  /// 表示高さ。幅はデザイン比率(560:660)から自動で決まる
  final double size;

  final PontaExpression expression;

  /// 頭の横にふわふわ浮かぶエフェクト（nullなら無し）
  final PontaEffect? effect;

  const PontaPuppet({
    super.key,
    this.size = 96,
    this.expression = PontaExpression.normal,
    this.effect,
  });

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
    String folder = 'ponta_parts',
  }) {
    final s = widget.size / _designH;
    final child = Image.asset(
      'assets/images/$folder/$name.png',
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

    // お願い顔は両手が顔パーツに含まれるので、ボディ側の腕を外す（手4本防止）
    final hideArms = widget.expression == PontaExpression.plead;

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
              if (!hideArms) ...[
                _part('arm_l',
                    left: 96, top: 420, width: 169,
                    angle: armA, pivot: const Alignment(0.8, 0.8)),
                _part('arm_r',
                    left: 302, top: 420, width: 152,
                    angle: -armA, pivot: const Alignment(-0.8, 0.8)),
              ],
              // 表情差分の頭。クロップの広さが表情ごとに違うので
              // 顔の大きさが揃うよう配置を個別調整している（tools/compose_mix.pyが原本）
              _head(headA),
              // エフェクトは頭の右上にふわふわ浮かべる
              if (widget.effect != null) _effect(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _effect() {
    final bob = sin(_t * 2 * pi / 1.6) * 8;
    final (name, width) = switch (widget.effect!) {
      PontaEffect.sweat => ('fx_sweat', 100.0),
      PontaEffect.fire => ('fx_fire', 130.0),
      PontaEffect.heart => ('fx_heart', 140.0),
      PontaEffect.meat => ('fx_meat', 130.0),
      PontaEffect.beer => ('fx_beer', 115.0),
      PontaEffect.rice => ('fx_rice', 130.0),
    };
    return _part(name,
        left: 445, top: -5 + bob, width: width, folder: 'ponta_macho');
  }

  Widget _head(double headA) {
    const pivot = Alignment(0, 0.85);
    // 表情シート（tools/extract_faces.py、ponta_faces/）は16種あるが
    // 直接対応しないものは近い見た目を流用: panic→worried, plead→sad,
    // sleepy→calm_closed, surprised→surprised_q
    final (name, top, width) = switch (widget.expression) {
      PontaExpression.normal => ('normal', 30.0, 407.0),
      PontaExpression.wink => ('wink_grin', 40.0, 407.0),
      PontaExpression.smug => ('smug_tongue', 32.0, 407.0),
      PontaExpression.shock => ('shock', 55.0, 407.0),
      PontaExpression.angry => ('angry', 32.0, 407.0),
      PontaExpression.panic => ('worried', 20.0, 407.0),
      PontaExpression.plead => ('sad', 45.0, 407.0),
      PontaExpression.sleepy => ('calm_closed', 55.0, 407.0),
      PontaExpression.cry => ('cry', 20.0, 407.0),
      PontaExpression.surprised => ('surprised_q', 20.0, 407.0),
    };
    return _part(name,
        left: 77, top: top, width: width,
        angle: headA, pivot: pivot, folder: 'ponta_faces');
  }
}
