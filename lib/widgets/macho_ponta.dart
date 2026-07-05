import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/sfx_service.dart';

/// 💪 ムキムキぽんぽこ（直立ウインクの1形態のみ）。
/// ボディは assets/images/ponta_macho/（tools/extract_macho.py で切り出し、
/// 配置は tools/compose_macho.py の stand_pose が原本）、
/// 頭はマッチョシートのドヤ頭がデカすぎたため既存の head_wink を小さめに代用。
/// 腕組み（head_arm_l）は腕1本フュージョンが化け物に見えるため不採用。
/// 表情差し替えはしない方針（ややこしくなるのでムキムキは1形態だけ）
class MachoPonta extends StatefulWidget {
  /// 表示高さ。幅はデザイン比率(280:370)から自動で決まる
  final double size;

  const MachoPonta({super.key, this.size = 120});

  @override
  State<MachoPonta> createState() => _MachoPontaState();
}

class _MachoPontaState extends State<MachoPonta>
    with SingleTickerProviderStateMixin {
  // デザイン座標系（tools/compose_macho.py と同じ数値）
  static const _designW = 280.0;
  static const _designH = 370.0;

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

  Widget _part(
    String name, {
    required double left,
    required double top,
    required double width,
    double angle = 0,
    Alignment pivot = Alignment.center,
    bool flip = false,
    String folder = 'ponta_macho',
  }) {
    final s = widget.size / _designH;
    Widget child = Image.asset(
      'assets/images/$folder/$name.png',
      width: width * s,
      filterQuality: FilterQuality.medium,
    );
    if (flip) {
      child = Transform.flip(flipX: true, child: child);
    }
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
    final tailA = sin(_t * 2 * pi / 1.8) * 0.09;
    final headA = sin(_t * 2 * pi / 3.3) * 0.03;
    final armA = sin(_t * 2 * pi / 2.5) * 0.04;
    final breathe = sin(_t * 2 * pi / 2.2) * 1.4;
    final jumpY = _jumpT < 1.0 ? -sin(pi * _jumpT) * widget.size * 0.10 : 0.0;

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
              // 後ろ→前の順（tools/compose_macho.py stand_poseと同じ）
              _part('tail',
                  left: 175, top: 195, width: 107,
                  angle: tailA, pivot: const Alignment(-0.8, 0.9)),
              _part('leg_l', left: 60, top: 215, width: 68),
              _part('leg_r', left: 150, top: 215, width: 71),
              _part('arm_r_down',
                  left: 28, top: 135, width: 66, flip: true,
                  angle: armA, pivot: const Alignment(0.5, -0.8)),
              _part('arm_r_down',
                  left: 188, top: 135, width: 66,
                  angle: -armA, pivot: const Alignment(-0.5, -0.8)),
              _part('body', left: 68, top: 130, width: 146),
              // 頭は既存のwink（体中心x=141に合わせて幅200、胸筋が見えるよう高め）
              _part('head_wink',
                  left: 41, top: 10, width: 200,
                  angle: headA, pivot: const Alignment(0, 0.85),
                  folder: 'ponta_parts'),
            ],
          ),
        ),
      ),
    );
  }
}
