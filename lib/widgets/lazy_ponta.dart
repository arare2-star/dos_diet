import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/sfx_service.dart';

/// 😴 寝そべりぽんぽこ。「課金しないと働かないぽん」用の1枚絵ポーズ
/// （assets/images/ponta_macho/pose_lie.png、MachoPontaと同じく1枚絵のまま使用）。
/// 呼吸のゆる動き（寝息）＋タップでぴょん
class LazyPonta extends StatefulWidget {
  /// 表示高さ。幅は画像本来の比率のまま自動で決まる
  final double size;

  const LazyPonta({super.key, this.size = 120});

  @override
  State<LazyPonta> createState() => _LazyPontaState();
}

class _LazyPontaState extends State<LazyPonta>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;
  double _jumpT = 1.0; // 1.0=ジャンプしていない

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
    if (mounted) setState(() {});
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    Sfx.play('pon');
    setState(() => _jumpT = 0);
  }

  @override
  Widget build(BuildContext context) {
    // 寝息のゆるい上下動
    final breathe = sin(_t * 2 * pi / 2.6) * widget.size * 0.015;
    final jumpY = _jumpT < 1.0 ? -sin(pi * _jumpT) * widget.size * 0.10 : 0.0;

    return GestureDetector(
      onTap: _onTap,
      child: Transform.translate(
        offset: Offset(0, jumpY + breathe),
        child: Image.asset(
          'assets/images/ponta_macho/pose_lie.png',
          height: widget.size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
