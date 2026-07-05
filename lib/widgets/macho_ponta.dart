import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/sfx_service.dart';

/// 💪 ムキムキぽんぽこ。
/// マッチョ仕様書シートの「ポーズ例・右から3番目」（片腕フレックス＋ドヤ横目）を
/// 1枚絵のまま使用（tools/extract_macho.py の pose_flex、138x164）。
/// パーツ合成は腕の本数や顔位置の事故が起きやすいため不採用
/// （経緯: 腕組み合成→化け物、wink頭載せ→顔位置が変、で1枚絵に落ち着いた）。
/// 呼吸のゆる動き＋タップでぴょん
class MachoPonta extends StatefulWidget {
  /// 表示高さ。幅は素材比率(138:164)から自動で決まる
  final double size;

  const MachoPonta({super.key, this.size = 120});

  @override
  State<MachoPonta> createState() => _MachoPontaState();
}

class _MachoPontaState extends State<MachoPonta>
    with SingleTickerProviderStateMixin {
  static const _aspect = 138 / 164;

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
    final breathe = sin(_t * 2 * pi / 2.2) * widget.size * 0.008;
    // 筋肉のパンプ感（ごく僅かな伸縮）
    final pump = 1.0 + sin(_t * 2 * pi / 2.2) * 0.008;
    final jumpY = _jumpT < 1.0 ? -sin(pi * _jumpT) * widget.size * 0.10 : 0.0;

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: widget.size * _aspect,
        height: widget.size,
        child: Transform.translate(
          offset: Offset(0, jumpY + breathe),
          child: Transform.scale(
            scaleY: pump,
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/ponta_macho/pose_flex.png',
              height: widget.size,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
