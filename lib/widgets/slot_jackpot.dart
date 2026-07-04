import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/sfx_service.dart';
import '../theme.dart';
import 'ponta_puppet.dart';

/// 当たりの格。演出の派手さが変わる
enum SlotRank {
  jackpot, // 激アツ（レインボー）
  win, // 通常の当たり（ゴールド）
}

class SlotTriggerResult {
  final SlotRank rank;
  final int number; // リールで回す数字
  final String unit; // 数字の単位ラベル
  final String title; // 結果発表の見出し
  final String message; // ぽんぽこのセリフ

  const SlotTriggerResult({
    required this.rank,
    required this.number,
    required this.unit,
    required this.title,
    required this.message,
  });
}

/// パチスロ演出のトリガー判定
class SlotTrigger {
  /// 食事を記録した直後に呼ぶ。当たりなら演出内容を返し、外れなら null
  static SlotTriggerResult? check({
    required int entryCalories,
    required String mealType,
    required int dayTotal,
    required int dailyGoal,
  }) {
    // 🌈 777は問答無用でフィーバー
    if (entryCalories == 777) {
      return const SlotTriggerResult(
        rank: SlotRank.jackpot,
        number: 777,
        unit: 'kcal',
        title: 'フィーバー',
        message: '777だぽん！！今日のお前は持ってるぽん！🎰',
      );
    }
    // 🎯 合計が目標カロリーぴったり
    if (dayTotal == dailyGoal) {
      return SlotTriggerResult(
        rank: SlotRank.jackpot,
        number: dayTotal,
        unit: 'kcal / 目標ぴったり',
        title: 'ぴったり賞',
        message: '合計が目標ぴったりだぽん！？神業だぽん…！',
      );
    }
    // 🎰 記録したカロリーがゾロ目
    if (_isRepdigit(entryCalories)) {
      return SlotTriggerResult(
        rank: SlotRank.win,
        number: entryCalories,
        unit: 'kcal',
        title: 'ゾロ目',
        message: 'ゾロ目だぽん！なんかツイてるぽん！',
      );
    }
    // 🎰 今日の合計がゾロ目
    if (_isRepdigit(dayTotal)) {
      return SlotTriggerResult(
        rank: SlotRank.win,
        number: dayTotal,
        unit: 'kcal / 今日の合計',
        title: '合計ゾロ目',
        message: '今日の合計がゾロ目だぽん！',
      );
    }
    // 🏆 夕食まで記録して目標内（1日の締めとして扱う）
    if (mealType == 'dinner' &&
        dayTotal <= dailyGoal &&
        dayTotal >= dailyGoal * 0.5) {
      return SlotTriggerResult(
        rank: SlotRank.win,
        number: dayTotal,
        unit: 'kcal / 目標 $dailyGoal',
        title: '目標達成',
        message: '夕食まで食べて目標内だぽん！今日は完璧だぽん！',
      );
    }
    return null;
  }

  /// 3桁以上のゾロ目か（111, 222, ..., 999, 1111, ...）
  static bool _isRepdigit(int n) {
    if (n < 111) return false;
    final s = n.toString();
    return s.split('').toSet().length == 1;
  }
}

/// スロット演出を全画面オーバーレイで表示する
Future<void> showSlotOverlay(BuildContext context, SlotTriggerResult result) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    barrierLabel: 'slot',
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _SlotOverlay(result: result),
  );
}

class _SlotOverlay extends StatefulWidget {
  final SlotTriggerResult result;

  const _SlotOverlay({required this.result});

  @override
  State<_SlotOverlay> createState() => _SlotOverlayState();
}

class _SlotOverlayState extends State<_SlotOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _resultCtrl;
  late final AnimationController _confetti;
  late final AnimationController _pulse;
  late final AnimationController _burst; // サンバースト回転
  late final AnimationController _cutin; // 激アツカットイン

  late final List<int> _digits;
  late final List<List<int>> _strips;
  late final List<int> _stopsMs; // 各リールの停止時刻(ms)
  late final int _totalMs;
  late final List<double> _stopFracs; // 各リールが止まるタイミング（0〜1）
  late final List<_ConfettiParticle> _particles;
  late final bool _isReach; // 最後の1本以外が同じ数字で止まる

  bool _showResult = false;
  bool _reachShown = false;

  static const _reelStopHaptics = HapticFeedback.mediumImpact;

  @override
  void initState() {
    super.initState();
    final rand = Random();

    _digits = widget.result.number
        .toString()
        .split('')
        .map(int.parse)
        .toList();

    // リーチ判定: 最後の1本を残して全リールが同じ数字（ゾロ目系は必ずリーチ）
    _isReach = _digits.length >= 3 &&
        _digits.sublist(0, _digits.length - 1).toSet().length == 1;

    // 各リールの停止時刻: 1本目1.0s、以降0.7s間隔。
    // 最後の1本はタメる（リーチなら「リーチ！」を見せるためさらに延長）
    final stopsMs = <int>[];
    for (var i = 0; i < _digits.length; i++) {
      var t = 1000 + 700 * i;
      if (i == _digits.length - 1) t += _isReach ? 1700 : 600;
      stopsMs.add(t);
    }
    _stopsMs = stopsMs;
    _totalMs = stopsMs.last;
    final totalMs = _totalMs;
    _stopFracs = stopsMs.map((t) => t / totalMs).toList();

    // リールの帯: ランダムな数字の列の末尾に目標の数字
    _strips = [
      for (var i = 0; i < _digits.length; i++)
        [
          for (var j = 0; j < 18 + i * 12; j++) rand.nextInt(10),
          _digits[i],
        ],
    ];

    _particles = List.generate(130, (_) => _ConfettiParticle(rand));

    _spin = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _cutin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // リール回転音（ループ）。停止のたびにハプティクス＋停止音
    Sfx.startLoop('spin_loop', volume: 0.6);
    for (final t in stopsMs) {
      Future.delayed(Duration(milliseconds: t), () {
        if (!mounted) return;
        _reelStopHaptics();
        Sfx.play('reel_stop');
      });
    }

    // リーチ発生: 最後から2本目が止まった直後に「リーチ！」を出す
    if (_isReach) {
      Future.delayed(
          Duration(milliseconds: _stopsMs[_digits.length - 2] + 80), () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        Sfx.play('reach');
        setState(() => _reachShown = true);
      });
    }

    // 激アツはラスト停止前にぽんぽこカットインが横切る
    if (widget.result.rank == SlotRank.jackpot) {
      Future.delayed(Duration(milliseconds: _totalMs - 1450), () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        Sfx.play('cutin');
        _cutin.forward();
      });
    }

    _spin.forward().whenComplete(() {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Sfx.stopLoop();
      Sfx.play(_isJackpot ? 'fanfare_jackpot' : 'fanfare_win');
      setState(() => _showResult = true);
      _resultCtrl.forward();
      _confetti.repeat();
    });
  }

  @override
  void dispose() {
    Sfx.stopLoop();
    _spin.dispose();
    _resultCtrl.dispose();
    _confetti.dispose();
    _pulse.dispose();
    _burst.dispose();
    _cutin.dispose();
    super.dispose();
  }

  bool get _isJackpot => widget.result.rank == SlotRank.jackpot;

  /// 期待度示唆の色（回転中のオーラ）。激アツは赤、通常はオレンジ
  Color get _auraColor =>
      _isJackpot ? const Color(0xFFFF1744) : AppTheme.secondary;

  static const _rainbow = [
    Color(0xFFFF5252),
    Color(0xFFFFB300),
    Color(0xFFFFEE58),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // 結果発表後のみタップで閉じられる
        onTap: _showResult ? () => Navigator.pop(context) : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
        children: [
          // 背景の回転サンバースト（リーチ・結果発表で強まる）
          AnimatedBuilder(
            animation: _burst,
            builder: (_, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _SunburstPainter(
                rotation: _burst.value * 2 * pi,
                colors: _isJackpot
                    ? _rainbow
                    : const [Color(0xFFFFB300), Color(0xFFFFE082)],
                alpha: _showResult ? 0.30 : (_reachShown ? 0.20 : 0.08),
              ),
            ),
          ),
          // 回転中の期待度オーラ（ふちが脈打つ）
          if (!_showResult)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      _auraColor.withValues(
                        alpha: (0.15 + 0.25 * _pulse.value) *
                            (_reachShown ? 1.6 : 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 紙吹雪
          if (_showResult)
            AnimatedBuilder(
              animation: _confetti,
              builder: (_, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  progress: _confetti.value,
                  particles: _particles,
                  colors: _isJackpot
                      ? _rainbow
                      : const [
                          AppTheme.secondary,
                          AppTheme.warning,
                          AppTheme.primary,
                          Colors.white,
                        ],
                ),
              ),
            ),
          // 本体
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showResult) _buildTitle(),
                  if (_reachShown && !_showResult) _buildReachText(),
                  const SizedBox(height: 24),
                  _buildReels(),
                  const SizedBox(height: 12),
                  Text(
                    widget.result.unit,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_showResult) _buildResultCard(),
                ],
              ),
            ),
          ),
          // 激アツカットイン（ぽんぽこがズバーンと横切る）
          if (_isJackpot) _buildCutin(context),
          // 結果発表の瞬間のフラッシュ（激アツは金色）
          if (_showResult)
            AnimatedBuilder(
              animation: _resultCtrl,
              builder: (_, _) {
                final flash = (1 - _resultCtrl.value * 4).clamp(0.0, 1.0);
                return IgnorePointer(
                  child: Container(
                    color: (_isJackpot
                            ? const Color(0xFFFFE082)
                            : Colors.white)
                        .withValues(alpha: flash),
                  ),
                );
              },
            ),
        ],
        ),
      ),
    );
  }

  /// リーチ中の煽りテキスト（脈打つ金グラデ）
  Widget _buildReachText() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => Transform.scale(
        scale: 1 + _pulse.value * 0.12,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFFF176),
              Color(0xFFFFB300),
              Color(0xFFFF7043),
            ],
          ).createShader(bounds),
          child: Text(
            'リーチ！！',
            style: GoogleFonts.nunito(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 激アツカットイン: 色フラッシュ→帯が開いて「激アツ！！」
  Widget _buildCutin(BuildContext context) {
    return AnimatedBuilder(
      animation: _cutin,
      builder: (_, _) {
        final t = _cutin.value;
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        // 帯は最初と最後にシュッと開閉する
        final band = t < 0.15
            ? t / 0.15
            : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
        final flash = (1 - t * 3.5).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Stack(
            children: [
              Container(color: _auraColor.withValues(alpha: flash * 0.55)),
              Center(
                child: Transform.scale(
                  scaleY: band,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3E0A0A),
                          Color(0xFFB71C1C),
                          Color(0xFF3E0A0A),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 24),
                      ],
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFF176), Color(0xFFFF8A65)],
                        ).createShader(bounds),
                        child: Text(
                          '激アツ！！',
                          style: GoogleFonts.nunito(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    final title = Text(
      '✨ ${widget.result.title} ✨',
      style: GoogleFonts.nunito(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
    return ScaleTransition(
      scale: CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut),
      child: _isJackpot
          ? ShaderMask(
              shaderCallback: (bounds) =>
                  const LinearGradient(colors: _rainbow).createShader(bounds),
              child: title,
            )
          : title,
    );
  }

  Widget _buildReels() {
    final reelWidth = _digits.length >= 4 ? 58.0 : 68.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _digits.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildReel(i, reelWidth),
          ),
      ],
    );
  }

  Widget _buildReel(int index, double width) {
    const height = 96.0;
    final anim = CurvedAnimation(
      parent: _spin,
      curve: Interval(0, _stopFracs[index], curve: Curves.easeOutCubic),
    );
    final strip = _strips[index];

    return AnimatedBuilder(
      animation: anim,
      builder: (_, _) {
        final offset = anim.value * (strip.length - 1);
        final i = offset.floor().clamp(0, strip.length - 1);
        final frac = offset - i;
        final glow = _showResult && _isJackpot;

        // 停止直前はガタガタ震える／リーチ中は停止済みリールが金縁で光る
        final tMs = _spin.value * _totalMs;
        final untilStop = _stopsMs[index] - tMs;
        var dx = 0.0, dy = 0.0;
        if (untilStop > 0 && untilStop < 450) {
          final k = 1 - untilStop / 450;
          dx = sin(tMs * 0.09 + index * 1.7) * 3.5 * k;
          dy = cos(tMs * 0.13 + index) * 2.5 * k;
        }
        final stopped = tMs >= _stopsMs[index];
        final reachGlow = _reachShown && !_showResult && stopped;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: glow
                    ? _rainbow[index % _rainbow.length]
                    : reachGlow
                        ? const Color(0xFFFFB300)
                        : AppTheme.primary,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (glow || reachGlow ? _auraColor : AppTheme.primary)
                      .withValues(alpha: reachGlow ? 0.7 : 0.5),
                  blurRadius: reachGlow ? 24 : 16,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                _reelDigit(strip[i], -frac * height, height),
                if (i + 1 < strip.length)
                  _reelDigit(strip[i + 1], (1 - frac) * height, height),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reelDigit(int digit, double dy, double height) {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Center(
          child: Text(
            '$digit',
            style: GoogleFonts.nunito(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PontaPuppet(size: 76),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.result.message,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _pulse,
            child: Text(
              'タップで閉じる',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double x; // 0〜1の横位置
  final double startY;
  final double speed;
  final double size;
  final double phase;
  final double spin;
  final int colorIndex;
  final bool star; // 金色の星（紙吹雪に混ざるご褒美感）

  _ConfettiParticle(Random rand)
      : x = rand.nextDouble(),
        startY = rand.nextDouble(),
        speed = 0.8 + rand.nextDouble() * 0.8,
        size = 6 + rand.nextDouble() * 6,
        phase = rand.nextDouble() * 2 * pi,
        spin = (rand.nextDouble() - 0.5) * 8,
        colorIndex = rand.nextInt(1 << 16),
        star = rand.nextDouble() < 0.28;
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;
  final List<Color> colors;

  _ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.colors,
  });

  static const _golds = [Color(0xFFFFD54F), Color(0xFFFFB300)];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      // 上から降り続けるようにループさせる
      final y = ((p.startY + progress * p.speed) % 1.15) - 0.075;
      final x = p.x + sin(progress * 2 * pi * 2 + p.phase) * 0.03;

      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(progress * 2 * pi * p.spin + p.phase);
      if (p.star) {
        paint.color = _golds[p.colorIndex % _golds.length];
        canvas.drawPath(_starPath(p.size * 0.7), paint);
      } else {
        paint.color = colors[p.colorIndex % colors.length];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  static Path _starPath(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final point = Offset(cos(a) * radius, sin(a) * radius);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 背景で回転する放射ライン（サンバースト）
class _SunburstPainter extends CustomPainter {
  final double rotation;
  final List<Color> colors;
  final double alpha;

  _SunburstPainter({
    required this.rotation,
    required this.colors,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    const rayCount = 24; // 偶数。1本おきに塗る
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    final sweep = 2 * pi / rayCount;
    final paint = Paint();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    for (var i = 0; i < rayCount; i += 2) {
      paint.color = colors[(i ~/ 2) % colors.length].withValues(alpha: alpha);
      final a0 = i * sweep;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(cos(a0) * radius, sin(a0) * radius)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          a0,
          sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunburstPainter old) =>
      old.rotation != rotation || old.alpha != alpha || old.colors != colors;
}
