import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// 🦝 画面の内側をうろちょろするドット絵ミニたぬき。
/// スプライトは画像ファイルではなくピクセルマップをCustomPainterで直接描画する。
/// 画面全体に被せても、たぬき本体以外はタッチを素通しする。
class MiniTanukiLayer extends StatelessWidget {
  const MiniTanukiLayer({super.key});

  @override
  Widget build(BuildContext context) {
    // Stack自体はヒットテストを持たないので、たぬき以外の領域はタッチが下に抜ける
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          MiniTanuki(
            areaWidth: constraints.maxWidth,
            areaHeight: constraints.maxHeight,
          ),
        ],
      ),
    );
  }
}

class MiniTanuki extends StatefulWidget {
  final double areaWidth;
  final double areaHeight;

  /// たぬきの表示高さ。幅はスプライト比率(28:24)から自動で決まる
  final double size;

  const MiniTanuki({
    super.key,
    required this.areaWidth,
    required this.areaHeight,
    this.size = 46,
  });

  @override
  State<MiniTanuki> createState() => _MiniTanukiState();
}

enum _TanukiState { idle, walk }

class _MiniTanukiState extends State<MiniTanuki>
    with SingleTickerProviderStateMixin {
  static const _speed = 36.0; // px/s
  final _rand = Random();

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  _TanukiState _state = _TanukiState.idle;

  /// 画面内側の縁を一周する周回路上の位置（弧長）。
  /// 下辺（左→右）→右壁（上へ）→上辺（右→左）→左壁（下へ）の順に一周する
  double _s = 0;
  int _dir = 1; // +1=上記の順回り、-1=逆回り
  double _remaining = 0; // 歩く残り距離
  bool _facingRight = true;
  double _stateTimer = 2.0; // 今の状態の残り秒数（idle用）
  double _walkTime = 0; // 歩行アニメの経過秒数

  static const _margin = 2.0; // 縁からの足元の距離
  double get _spriteW => widget.size * _TanukiSpritePainter.aspect;
  double get _edgeW => max(1.0, widget.areaWidth - 2 * _margin);
  double get _edgeH => max(1.0, widget.areaHeight - 2 * _margin);
  double get _perimeter => 2 * (_edgeW + _edgeH);

  /// 弧長sから足元の位置（x:左から, y:下から）と回転角を返す。
  /// 回転角は「足がどの縁に着いているか」: 下辺0、右壁-π/2、上辺π（逆さま）、左壁π/2
  (double, double, double) _pose(double s) {
    var t = s % _perimeter;
    if (t < 0) t += _perimeter;
    if (t < _edgeW) return (_margin + t, _margin, 0);
    t -= _edgeW;
    if (t < _edgeH) return (widget.areaWidth - _margin, _margin + t, -pi / 2);
    t -= _edgeH;
    if (t < _edgeW) {
      return (widget.areaWidth - _margin - t, widget.areaHeight - _margin, pi);
    }
    t -= _edgeW;
    return (_margin, widget.areaHeight - _margin - t, pi / 2);
  }

  // まばたき
  double _blinkTimer = 3.0;
  bool _blinking = false;

  // タップ時のジャンプ＆セリフ
  double _jumpT = 1.0; // 1.0=ジャンプしていない
  String? _speech;
  double _speechTimer = 0;

  static const _speeches = [
    'ぽん！',
    'なんだぽん？',
    '見てないで記録するぽん',
    'くすぐったいぽん🍃',
    '暇なのかぽん？',
  ];

  @override
  void initState() {
    super.initState();
    // 最初は下辺のどこかからスタート
    _s = _spriteW + _rand.nextDouble() * max(1.0, _edgeW - _spriteW * 2);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;

    // まばたき
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) {
      _blinking = !_blinking;
      _blinkTimer = _blinking ? 0.12 : 2 + _rand.nextDouble() * 3;
    }

    // ジャンプ進行
    if (_jumpT < 1.0) _jumpT = min(1.0, _jumpT + dt * 2.5);

    // セリフの寿命
    if (_speech != null) {
      _speechTimer -= dt;
      if (_speechTimer <= 0) _speech = null;
    }

    switch (_state) {
      case _TanukiState.idle:
        _stateTimer -= dt;
        if (_stateTimer <= 0) {
          // 向きと距離を決めて縁に沿って歩き出す（角は曲がって続行）
          _dir = _rand.nextBool() ? 1 : -1;
          _remaining = 90 + _rand.nextDouble() * 420;
          // 周回の順方向はどの縁でもスプライトの右向きに当たる
          _facingRight = _dir > 0;
          _state = _TanukiState.walk;
        }
      case _TanukiState.walk:
        _walkTime += dt;
        final step = _speed * dt;
        _s = (_s + _dir * step) % _perimeter;
        _remaining -= step;
        if (_remaining <= 0) {
          _state = _TanukiState.idle;
          _stateTimer = 1.5 + _rand.nextDouble() * 4;
          _walkTime = 0;
        }
    }

    if (mounted) setState(() {});
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _jumpT = 0;
    _speech = _speeches[_rand.nextInt(_speeches.length)];
    _speechTimer = 1.6;
    // 立ち止まって反応する
    _state = _TanukiState.idle;
    _stateTimer = max(_stateTimer, 1.6);
  }

  @override
  Widget build(BuildContext context) {
    final walking = _state == _TanukiState.walk;
    // 歩行は4コマの足パタパタ（walk1→walk2→walk3→walk2、1コマ0.13秒）
    const walkCycle = [1, 2, 3, 2];
    final frame =
        walking ? walkCycle[(_walkTime / 0.13).floor() % walkCycle.length] : 0;
    final jumpY = _jumpT < 1.0 ? -sin(pi * _jumpT) * 16 : 0.0;

    final (fx, fy, theta) = _pose(_s);
    // 足元の縁から画面内側へ向かう単位ベクトル（吹き出しの置き場所に使う）
    final inward = Offset(sin(theta), cos(theta));
    final bubbleX = (fx + inward.dx * (widget.size + 18)).clamp(
      84.0,
      max(84.0, widget.areaWidth - 84.0),
    );
    final bubbleY = max(4.0, fy + inward.dy * (widget.size + 18) - 14);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 吹き出しは縁に関わらず常に正立で、たぬきの内側に出す
          if (_speech != null)
            Positioned(
              left: bubbleX - 80,
              bottom: bubbleY,
              child: SizedBox(
                width: 160,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _speech!,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // たぬき本体。足元（下辺中央）を軸に、着いている縁へ回転する
          Positioned(
            left: fx - _spriteW / 2,
            bottom: fy,
            child: GestureDetector(
              onTap: _onTap,
              child: Transform.rotate(
                angle: theta,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: _spriteW,
                  height: widget.size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 足元の影。ジャンプ中も縁に残り、薄くなる
                      Positioned(
                        left: _spriteW * 0.18,
                        right: _spriteW * 0.18,
                        bottom: 0,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(
                              alpha: 0.10 * (1 - 0.6 * (-jumpY / 16)),
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(20, 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(0, jumpY),
                          child: Transform.flip(
                            flipX: !_facingRight,
                            child: CustomPaint(
                              painter: _TanukiSpritePainter(
                                frame: frame,
                                blinking: _blinking,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 28x24のピクセルマップをそのまま描く（横向き・右向き基準）。
/// frame 0=待機、1〜3=歩行コマ。ドット絵はスクラッチパッドの tanuki_v4.py で生成。
class _TanukiSpritePainter extends CustomPainter {
  final int frame;
  final bool blinking;

  _TanukiSpritePainter({required this.frame, required this.blinking});

  static const int _cols = 28;
  static const int _rows = 24;
  static const double aspect = _cols / _rows;

  static const List<String> _idle = [
    "...................KKKK.....",
    "...............KKKKKGGKKKK..",
    "..............KKBKKGgKKKBKK.",
    "..............KBDKKKgKKKDBK.",
    "KKKK..........KBDBKKgKKBDBK.",
    "KBBKK.........KKKKKBBBKKKKK.",
    "BBDDKK.........KKBBBBBBBKK..",
    "BDDDBK........KKBBBBBBBBBKK.",
    "KDDBBKK.......KBBEDBBDEWDBK.",
    "KKBBBDKK......KBDEDBBDEEDBKK",
    ".KBBDDDKKKKKKKKBBBBBBBDCCNNK",
    ".KKDDDBBKBBBBBBBBBBBCCBCCCCK",
    "..KDBBBBBBBBBBBBBBBCCCCCCCCK",
    "..KKBBDBBBBBBBBBBBBCCCCBCCKK",
    "...KKDDBBBBBBBBCCCCBBBKKKKK.",
    "....KKBBBBBBBCCCCCCCCBK.....",
    ".....KKBBBBBBCCCCCCCCKK.....",
    "......KBBBBBBCCCCCCCCK......",
    "......KKBBBBBCCCCCCCCK......",
    "......KBBBDDBBBBBCDDKK......",
    "......KBBKDDKKKBBKDDK.......",
    "......KBBKDDK.KBBKDDK.......",
    "......KPPKDDK.KPPKDDK.......",
    "......KKKKKKK.KKKKKKK.......",
  ];

  static const List<String> _walk1 = [
    "...................KKKK.....",
    "...............KKKKKGGKKKK..",
    "..............KKBKKGgKKKBKK.",
    "..............KBDKKKgKKKDBK.",
    "KKKK..........KBDBKKgKKBDBK.",
    "KBBKK.........KKKKKBBBKKKKK.",
    "BBDDKK.........KKBBBBBBBKK..",
    "BDDDBK........KKBBBBBBBBBKK.",
    "KDDBBKK.......KBBEDBBDEWDBK.",
    "KKBBBDKK......KBDEDBBDEEDBKK",
    ".KBBDDDKKKKKKKKBBBBBBBDCCNNK",
    ".KKDDDBBKBBBBBBBBBBBCCBCCCCK",
    "..KDBBBBBBBBBBBBBBBCCCCCCCCK",
    "..KKBBDBBBBBBBBBBBBCCCCBCCKK",
    "...KKDDBBBBBBBBCCCCBBBKKKKK.",
    "....KKBBBBBBBCCCCCCCCBK.....",
    ".....KKBBBBBBCCCCCCCCKK.....",
    "......KBBBBBBCCCCCCCCK......",
    "......KKBBBBBCCCCCCCCK......",
    ".......KBBDBBBBCBBDKKK......",
    ".......KBBDKKKKKBBDK........",
    ".......KBBDK...KBBDK........",
    ".......KPPDK...KPPDK........",
    ".......KKKKK...KKKKK........",
  ];

  static const List<String> _walk2 = [
    "...............KKKKKGGKKKK..",
    "..............KKBKKGgKKKBKK.",
    "..............KBDKKKgKKKDBK.",
    "KKKK..........KBDBKKgKKBDBK.",
    "KBBKK.........KKKKKBBBKKKKK.",
    "BBDDKK.........KKBBBBBBBKK..",
    "BDDDBK........KKBBBBBBBBBKK.",
    "KDDBBKK.......KBBEDBBDEWDBK.",
    "KKBBBDKK......KBDEDBBDEEDBKK",
    ".KBBDDDKKKKKKKKBBBBBBBDCCNNK",
    ".KKDDDBBKBBBBBBBBBBBCCBCCCCK",
    "..KDBBBBBBBBBBBBBBBCCCCCCCCK",
    "..KKBBDBBBBBBBBBBBBCCCCBCCKK",
    "...KKDDBBBBBBBBCCCCBBBKKKKK.",
    "....KKBBBBBBBCCCCCCCCBK.....",
    ".....KKBBBBBBCCCCCCCCKK.....",
    "......KBBBBBBCCCCCCCCK......",
    "......KKBBBBBCCCCCCCCK......",
    "......KBBBBBBBBBBCCKKK......",
    "......KBBKDDKKKBBKDDK.......",
    "......KBBKDDK.KBBKDDK.......",
    "......KBBKDDK.KBBKDDK.......",
    "......KPPKDDK.KPPKDDK.......",
    "......KKKKKKK.KKKKKKK.......",
  ];

  static const List<String> _walk3 = [
    "...................KKKK.....",
    "...............KKKKKGGKKKK..",
    "..............KKBKKGgKKKBKK.",
    "..............KBDKKKgKKKDBK.",
    "KKKK..........KBDBKKgKKBDBK.",
    "KBBKK.........KKKKKBBBKKKKK.",
    "BBDDKK.........KKBBBBBBBKK..",
    "BDDDBK........KKBBBBBBBBBKK.",
    "KDDBBKK.......KBBEDBBDEWDBK.",
    "KKBBBDKK......KBDEDBBDEEDBKK",
    ".KBBDDDKKKKKKKKBBBBBBBDCCNNK",
    ".KKDDDBBKBBBBBBBBBBBCCBCCCCK",
    "..KDBBBBBBBBBBBBBBBCCCCCCCCK",
    "..KKBBDBBBBBBBBBBBBCCCCBCCKK",
    "...KKDDBBBBBBBBCCCCBBBKKKKK.",
    "....KKBBBBBBBCCCCCCCCBK.....",
    ".....KKBBBBBBCCCCCCCCKK.....",
    "......KBBBBBBCCCCCCCCK......",
    ".....KKKBBBBBCCCCCCCCK......",
    ".....KBBKBBDDBBBCCCDDK......",
    ".....KBBKKKDDKBBKKKDDK......",
    ".....KBBK.KDDKBBK.KDDK......",
    ".....KPPK.KDDKPPK.KDDK......",
    ".....KKKK.KKKKKKK.KKKK......",
  ];

  static const List<List<String>> _frames = [_idle, _walk1, _walk2, _walk3];

  static const Map<String, Color> _palette = {
    'K': Color(0xFF4E342E),
    'B': Color(0xFFC49A6C),
    'D': Color(0xFF6D4C41),
    'C': Color(0xFFF6E7C1),
    'G': Color(0xFF66BB6A),
    'g': Color(0xFF43A047),
    'E': Color(0xFF211816),
    'W': Color(0xFFFFFFFF),
    'N': Color(0xFF3E2723),
    'P': Color(0xFF563A30),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final sprite = _frames[frame];
    final cell = size.width / _cols;
    final paint = Paint();
    for (var y = 0; y < sprite.length; y++) {
      final row = sprite[y];
      for (var x = 0; x < row.length; x++) {
        var ch = row[x];
        if (ch == '.') continue;
        // まばたき中は目のピクセルをマスク色で塗りつぶす
        if (blinking && (ch == 'E' || ch == 'W')) ch = 'D';
        paint.color = _palette[ch]!;
        // セル境界の隙間が出ないよう少しだけ重ねて描く
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TanukiSpritePainter old) =>
      old.blinking != blinking || old.frame != frame;
}
