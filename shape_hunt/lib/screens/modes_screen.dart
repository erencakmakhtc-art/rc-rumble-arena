import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../controllers/game_controller.dart';
import '../data/world_countries.dart';
import '../models/game_mode.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';
import '../widgets/mode_glyph.dart';

/// Haritada iki bolum arasindaki yatay mesafe ve dugum yaricapi.
const double _kNodeGap = 118;
const double _kNodeR = 32;
const double _kMapPadL = 78;
const double _kMapPadR = 170;

/// Her dunyada kac bolum var.
const int _kLevelsPerWorld = 10;

class _World {
  final String name;
  final List<Color> sky;
  final Color road;
  final Color label;
  const _World(this.name, this.sky, this.road, this.label);
}

const List<_World> _kWorlds = [
  _World('Şeker Çayırı', [Color(0xFFBFE9FF), Color(0xFFDDF7E6)], Color(0xFFFFF4D6), Color(0xFF2E6B4F)),
  _World('Alacakaranlık Vadisi', [Color(0xFFFFB9A8), Color(0xFFB98AD9)], Color(0xFFFFE6D6), Color(0xFF5A1F4A)),
  _World('Yıldız Denizi', [Color(0xFF1E1B4B), Color(0xFF3B1E6B)], Color(0xFFD6D0FF), Color(0xFF3B1E6B)),
];

int _worldOf(int index) => (index ~/ _kLevelsPerWorld).clamp(0, _kWorlds.length - 1);

/// Harita: bolumler kivrimli bir yol uzerinde soldan saga dizilir, sirayla
/// acilir. Bir bolum gecilip haritaya donulunce yol bir sonraki bolume dogru
/// uzar ve yeni dugum acilir.
class ModesScreen extends StatefulWidget {
  final GameController controller;
  const ModesScreen({super.key, required this.controller});

  @override
  State<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends State<ModesScreen> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _reveal;
  final ScrollController _scroll = ScrollController();

  GameMode? _selected;

  /// Acilma animasyonu oynatilan dugumun indeksi (-1 = yok).
  int _revealIdx = -1;
  bool _revealSoundPlayed = false;
  double _viewW = 0;
  double _mapH = 0;

  GameController get c => widget.controller;
  int get _count => kModeOrder.length;

  int get _unlockedCount {
    var n = 0;
    for (final m in kModeOrder) {
      if (!c.isModeUnlocked(m)) break;
      n += 1;
    }
    return max(1, n);
  }

  /// Oyuncunun "su an" bulundugu bolum: acik ama gecilmemis ilk bolum.
  int get _currentIndex {
    for (var i = 0; i < _count; i++) {
      final m = kModeOrder[i];
      if (!c.isModeUnlocked(m)) return max(0, i - 1);
      if (!c.passedModes.contains(m)) return i;
    }
    return _count - 1;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _reveal.addListener(() {
      if (!_revealSoundPlayed && _reveal.value >= 0.6) {
        _revealSoundPlayed = true;
        AudioManager.instance.playCorrect();
      }
    });

    final unlocked = _unlockedCount;
    if (unlocked == c.mapRevealed + 1) _revealIdx = unlocked - 1;
    c.mapRevealed = max(c.mapRevealed, unlocked);
    _selected = kModeOrder[_currentIndex];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_revealIdx > 0) {
        _jumpTo(_revealIdx - 1);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        _reveal.forward();
        _animateTo(_revealIdx, ms: 1000);
      } else {
        _jumpTo(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _reveal.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- geometri ----

  double get _mapW => _kMapPadL + (_count - 1) * _kNodeGap + _kMapPadR;

  Offset _nodePos(int i) =>
      Offset(_kMapPadL + i * _kNodeGap, _mapH * 0.48 + sin(i * 0.85 + 0.3) * _mapH * 0.2);

  double _scrollTarget(int i) {
    if (!_scroll.hasClients) return 0;
    final t = _nodePos(i).dx - _viewW / 2;
    return t.clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
  }

  void _jumpTo(int i) {
    if (_scroll.hasClients) _scroll.jumpTo(_scrollTarget(i));
  }

  void _animateTo(int i, {int ms = 450}) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_scrollTarget(i), duration: Duration(milliseconds: ms), curve: Curves.easeInOutCubic);
  }

  void _select(int i) {
    AudioManager.instance.playClick();
    setState(() => _selected = kModeOrder[i]);
    _animateTo(i);
  }

  /// Yeni acilan dugum, animasyonun ilk %60'inda henuz kilitli gorunur.
  bool _visuallyLocked(int i) {
    if (i == _revealIdx && _reveal.value < 0.6) return true;
    return !c.isModeUnlocked(kModeOrder[i]);
  }

  @override
  Widget build(BuildContext context) {
    final passedCount = c.passedModes.where(kModeOrder.contains).length;
    final cur = _currentIndex;
    return Column(
      children: [
        _Header(controller: c, passed: passedCount, total: _count, world: _worldOf(cur)),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.85), width: 2.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, box) {
                    _viewW = box.maxWidth;
                    _mapH = box.maxHeight;
                    return SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: _mapW,
                        height: _mapH,
                        child: _buildMap(cur),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _DetailPanel(
          controller: c,
          mode: _selected ?? kModeOrder[cur],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMap(int cur) {
    final nodes = [for (var i = 0; i < _count; i++) _nodePos(i)];
    final unlocked = _unlockedCount;
    final children = <Widget>[
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) => CustomPaint(
              painter: _MapPainter(
                nodes: nodes,
                unlocked: unlocked,
                revealIdx: _revealIdx,
                revealT: _reveal.value,
              ),
            ),
          ),
        ),
      ),
    ];

    // Dunya tabelalari
    for (var w = 0; w < _kWorlds.length; w++) {
      final first = w * _kLevelsPerWorld;
      if (first >= _count) break;
      final open = c.isModeUnlocked(kModeOrder[first]);
      children.add(Positioned(
        left: nodes[first].dx - 44,
        top: _mapH - 38,
        child: _WorldBanner(index: w, open: open),
      ));
    }

    // Dugumler
    for (var i = 0; i < _count; i++) {
      final mode = kModeOrder[i];
      final p = nodes[i];
      children.add(Positioned(
        left: p.dx - 55,
        top: p.dy - _kNodeR,
        width: 110,
        child: AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) {
            var pop = 1.0;
            if (i == _revealIdx && _reveal.value >= 0.6) {
              final k = ((_reveal.value - 0.6) / 0.4).clamp(0.0, 1.0).toDouble();
              pop = 1 + 0.3 * sin(pi * k);
            }
            return Transform.scale(
              scale: pop,
              // Dairenin merkezinden buyusun (dugum yuksekliginin ust kismi).
              alignment: const Alignment(0, -0.45),
              child: _MapNode(
                mode: mode,
                index: i + 1,
                locked: _visuallyLocked(i),
                passed: c.passedModes.contains(mode),
                current: i == cur,
                selected: _selected == mode,
                dark: _worldOf(i) == 2,
                pulse: _pulse,
                onTap: () => _select(i),
              ),
            );
          },
        ),
      ));
    }

    // Oyuncu isaretcisi (ulke bayragi)
    final cp = nodes[cur];
    children.add(Positioned(
      left: cp.dx - 20,
      top: cp.dy - _kNodeR - 52,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _reveal]),
        builder: (context, child) {
          final hidden = cur == _revealIdx && _reveal.value < 0.95;
          final bounce = sin(_pulse.value * 2 * pi) * 5;
          return Opacity(
            opacity: hidden ? 0 : 1,
            child: Transform.translate(offset: Offset(0, bounce), child: child),
          );
        },
        child: _PlayerMarker(flag: flagEmoji(c.cc ?? 'TR')),
      ),
    ));

    // Harita sonu
    final last = nodes.last;
    children.add(Positioned(
      left: last.dx + 62,
      top: last.dy - 50,
      child: const _EndSign(),
    ));

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

// =============================================================================
// Ust bilgi
// =============================================================================

class _Header extends StatelessWidget {
  final GameController controller;
  final int passed;
  final int total;
  final int world;
  const _Header({required this.controller, required this.passed, required this.total, required this.world});

  @override
  Widget build(BuildContext context) {
    final done = passed >= total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: controller.goHome,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.75), Colors.white.withOpacity(0.5)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_rounded, size: 21, color: AppColors.inkSoft),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bölüm Haritası', style: baloo(22, FontWeight.w800, AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  done ? 'Tüm dünyaları fethettin!' : 'Dünya ${world + 1} · ${_kWorlds[world].name}',
                  style: baloo(12, FontWeight.w700, AppColors.inkPale),
                ),
                const SizedBox(height: 5),
                // Ilerleme cubugu
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white.withOpacity(0.6),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: total == 0 ? 0 : (passed / total).clamp(0.0, 1.0).toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(colors: [Color(0xFFFFD24D), Color(0xFFFFA000)]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$passed/$total', style: baloo(12, FontWeight.w800, AppColors.goldInk)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
              gradient: AppGradients.gold,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⚡', style: baloo(14, FontWeight.w800, AppColors.goldInkAlt)),
                const SizedBox(width: 5),
                Text('${controller.playsLeft}', style: baloo(16, FontWeight.w800, AppColors.goldInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Harita parcalari
// =============================================================================

class _MapNode extends StatelessWidget {
  final GameMode mode;
  final int index;
  final bool locked;
  final bool passed;
  final bool current;
  final bool selected;
  final bool dark;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _MapNode({
    required this.mode,
    required this.index,
    required this.locked,
    required this.passed,
    required this.current,
    required this.selected,
    required this.dark,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final def = kGameModes[mode]!;
    const size = _kNodeR * 2;

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: locked ? const [Color(0xFFE3E5F0), Color(0xFFA9AECB)] : def.accent,
        ),
        border: Border.all(
          color: passed ? const Color(0xFFFFC23A) : Colors.white,
          width: selected ? 4.5 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: locked ? Colors.black.withOpacity(0.15) : def.depth.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Opacity(opacity: locked ? 0.35 : 1, child: ModeGlyph(mode: mode, size: 36)),
    );

    Widget node = Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          left: -5,
          top: -5,
          child: _Badge(
            color: locked ? const Color(0xFF8C92B8) : AppColors.ink,
            child: Text('$index', style: baloo(11, FontWeight.w800, Colors.white, height: 1.0)),
          ),
        ),
        if (locked)
          const Positioned(
            right: -4,
            bottom: -4,
            child: _Badge(
              color: Color(0xFF6E739E),
              child: Icon(Icons.lock_rounded, size: 13, color: Colors.white),
            ),
          )
        else if (passed)
          const Positioned(
            right: -4,
            bottom: -4,
            child: _Badge(
              color: Color(0xFFFFB300),
              child: Icon(Icons.check_rounded, size: 15, color: Colors.white),
            ),
          ),
      ],
    );

    if (current && !locked) {
      node = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final s = sin(pulse.value * 2 * pi);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFE08A).withOpacity(0.55 + 0.3 * s),
                  blurRadius: 16 + 8 * s,
                  spreadRadius: 3 + 3 * s,
                ),
              ],
            ),
            child: Transform.scale(scale: 1 + 0.06 * s, child: child),
          );
        },
        child: node,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          node,
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(dark ? 0.9 : 0.8),
            ),
            child: Text(
              def.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: baloo(10.5, FontWeight.w800, locked ? AppColors.inkPale : AppColors.ink),
            ),
          ),
          if (current && !locked) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(colors: [Color(0xFFFFD24D), Color(0xFFFFA000)]),
              ),
              child: Text(passed ? 'TEKRAR' : 'SIRADA', style: baloo(10, FontWeight.w800, const Color(0xFF6B3A00))),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Badge({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _PlayerMarker extends StatelessWidget {
  final String flag;
  const _PlayerMarker({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(flag, style: const TextStyle(fontSize: 20, height: 1.0)),
        ),
        CustomPaint(size: const Size(14, 8), painter: _PointerPainter()),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}

class _WorldBanner extends StatelessWidget {
  final int index;
  final bool open;
  const _WorldBanner({required this.index, required this.open});

  @override
  Widget build(BuildContext context) {
    final w = _kWorlds[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.88),
        border: Border.all(color: w.label.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(open ? '🗺️' : '🔒', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            'DÜNYA ${index + 1} · ${w.name}',
            style: baloo(11, FontWeight.w800, w.label, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _EndSign extends StatelessWidget {
  const _EndSign();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🏆', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withOpacity(0.9),
          ),
          child: Text(
            'Yeni dünyalar\nyakında',
            textAlign: TextAlign.center,
            style: baloo(11, FontWeight.w800, AppColors.inkSoft, height: 1.15),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Harita zemini ve yol
// =============================================================================

class _MapPainter extends CustomPainter {
  final List<Offset> nodes;
  final int unlocked;
  final int revealIdx;
  final double revealT;

  _MapPainter({
    required this.nodes,
    required this.unlocked,
    required this.revealIdx,
    required this.revealT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;
    _worlds(canvas, size);
    _road(canvas);
  }

  /// Dunyalarin sinirlari: iki dunyanin son/ilk dugumlerinin ortasi.
  (double, double) _zone(int w, Size size) {
    final first = w * _kLevelsPerWorld;
    final lastIdx = min(nodes.length - 1, first + _kLevelsPerWorld - 1);
    final x0 = w == 0 ? 0.0 : (nodes[first - 1].dx + nodes[first].dx) / 2;
    final x1 = (w == _kWorlds.length - 1 || lastIdx + 1 >= nodes.length)
        ? size.width
        : (nodes[lastIdx].dx + nodes[lastIdx + 1].dx) / 2;
    return (x0, x1);
  }

  void _worlds(Canvas canvas, Size size) {
    for (var w = 0; w < _kWorlds.length; w++) {
      if (w * _kLevelsPerWorld >= nodes.length) break;
      final (x0, x1) = _zone(w, size);
      final rect = Rect.fromLTRB(x0, 0, x1, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _kWorlds[w].sky,
          ).createShader(rect),
      );
      canvas.save();
      canvas.clipRect(rect);
      switch (w) {
        case 0:
          _meadow(canvas, rect);
        case 1:
          _dusk(canvas, rect);
        default:
          _space(canvas, rect);
      }
      canvas.restore();
      if (w > 0) _cloudWall(canvas, x0, size.height);
    }
  }

  void _meadow(Canvas canvas, Rect r) {
    // Bulutlar
    final cloud = Paint()..color = Colors.white.withOpacity(0.85);
    for (var x = r.left + 60; x < r.right; x += 230) {
      final y = r.height * (0.12 + 0.05 * sin(x * 0.01));
      canvas.drawCircle(Offset(x, y), 16, cloud);
      canvas.drawCircle(Offset(x + 18, y + 4), 13, cloud);
      canvas.drawCircle(Offset(x - 17, y + 5), 12, cloud);
    }
    // Tepeler
    for (final (base, amp, color, f) in [
      (0.82, 0.08, const Color(0xFFA8E6A1), 0.012),
      (0.9, 0.06, const Color(0xFF7CCB7A), 0.018),
    ]) {
      final path = Path()..moveTo(r.left, r.bottom);
      for (var x = r.left; x <= r.right + 10; x += 10) {
        path.lineTo(x, r.height * base - r.height * amp * (0.5 + 0.5 * sin(x * f)));
      }
      path
        ..lineTo(r.right, r.bottom)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    // Cicekler
    for (var x = r.left + 30; x < r.right; x += 70) {
      final y = r.height * 0.93 + 6 * sin(x);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = const Color(0xFFFF9AC2));
      canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = const Color(0xFFFFF3B0));
    }
  }

  void _dusk(Canvas canvas, Rect r) {
    // Gunes
    final sun = Offset(r.left + r.width * 0.55, r.height * 0.3);
    canvas.drawCircle(
      sun,
      60,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFFF1C2), Color(0x00FFB86B)])
            .createShader(Rect.fromCircle(center: sun, radius: 60)),
    );
    // Daglar
    for (final (base, height, color, phase) in [
      (0.86, 0.28, const Color(0xFF9A6BB5), 0.0),
      (0.94, 0.18, const Color(0xFF6E4A8F), 1.3),
    ]) {
      final path = Path()..moveTo(r.left, r.bottom);
      var i = 0;
      for (var x = r.left; x <= r.right + 60; x += 60) {
        final up = i.isOdd ? (0.55 + 0.45 * (0.5 + 0.5 * sin(i * 1.7 + phase))) : 0.2;
        path.lineTo(x, r.height * base - r.height * height * up);
        i += 1;
      }
      path
        ..lineTo(r.right, r.bottom)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  void _space(Canvas canvas, Rect r) {
    final rnd = Random(5);
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < (r.width / 9).round(); i++) {
      final p = Offset(r.left + rnd.nextDouble() * r.width, rnd.nextDouble() * r.height);
      star.color = Colors.white.withOpacity(0.4 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(p, 0.6 + rnd.nextDouble() * 1.3, star);
    }
    // Halkali gezegen
    final pc = Offset(r.left + r.width * 0.35, r.height * 0.8);
    canvas.drawCircle(
      pc,
      34,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFB3D8), Color(0xFF8E3FD1)],
        ).createShader(Rect.fromCircle(center: pc, radius: 34)),
    );
    canvas.save();
    canvas.translate(pc.dx, pc.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 110, height: 24),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFE0A8).withOpacity(0.8),
    );
    canvas.restore();
    // Uzak gezegen
    canvas.drawCircle(
      Offset(r.left + r.width * 0.8, r.height * 0.2),
      14,
      Paint()..color = const Color(0xFF5CE1F0).withOpacity(0.75),
    );
  }

  /// Iki dunya arasindaki gecit: yumusak bulut duvari.
  void _cloudWall(Canvas canvas, double x, double h) {
    final p = Paint()..color = Colors.white.withOpacity(0.9);
    for (var y = -10.0; y < h + 20; y += 26) {
      final dx = 8 * sin(y * 0.09);
      canvas.drawCircle(Offset(x + dx, y), 22, p);
      canvas.drawCircle(Offset(x + dx - 16, y + 12), 15, p);
      canvas.drawCircle(Offset(x + dx + 16, y + 10), 15, p);
    }
  }

  Path _segment(int i) {
    final a = nodes[i];
    final b = nodes[i + 1];
    final mx = (a.dx + b.dx) / 2;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
  }

  void _road(Canvas canvas) {
    final segs = [for (var i = 0; i < nodes.length - 1; i++) _segment(i)];

    // Yol govdesi: once kenar, sonra ic.
    for (var i = 0; i < segs.length; i++) {
      final road = _kWorlds[_worldOf(i)].road;
      canvas.drawPath(
        segs[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(road, Colors.black, 0.22)!.withOpacity(0.55),
      );
    }
    for (var i = 0; i < segs.length; i++) {
      canvas.drawPath(
        segs[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 19
          ..strokeCap = StrokeCap.round
          ..color = _kWorlds[_worldOf(i)].road,
      );
    }

    // Ilerleme: acik parca altin noktalar, kilitli parca gri kesikli.
    final gold = Paint()..color = const Color(0xFFFFB300);
    final gray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8C92CD).withOpacity(0.55);
    for (var i = 0; i < segs.length; i++) {
      final target = i + 1;
      var goldUpTo = 0.0;
      if (target < unlocked) goldUpTo = 1.0;
      if (target == revealIdx) goldUpTo = (revealT / 0.6).clamp(0.0, 1.0).toDouble();
      for (final m in segs[i].computeMetrics()) {
        final len = m.length;
        final goldLen = len * goldUpTo;
        // Altin noktalar
        for (var d = 10.0; d < goldLen - 6; d += 15) {
          final t = m.getTangentForOffset(d);
          if (t != null) canvas.drawCircle(t.position, 3.4, gold);
        }
        // Kesikli gri
        for (var d = goldLen + 8; d < len - 10; d += 16) {
          canvas.drawPath(m.extractPath(d, min(d + 8, len - 10)), gray);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.revealT != revealT || old.unlocked != unlocked || old.nodes.length != nodes.length ||
      (old.nodes.isNotEmpty && nodes.isNotEmpty && old.nodes.first != nodes.first);
}

// =============================================================================
// Alt panel: secili bolumun detayi ve Oyna butonu
// =============================================================================

class _DetailPanel extends StatelessWidget {
  final GameController controller;
  final GameMode mode;
  const _DetailPanel({required this.controller, required this.mode});

  String _fmtBest(int v) {
    if (!GameController.lowerIsBetter(mode)) return '$v puan';
    if (v < 1000) return '$v ms';
    return '${(v / 1000).toStringAsFixed(2)} sn';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final def = kGameModes[mode]!;
    final idx = kModeOrder.indexOf(mode);
    final locked = !c.isModeUnlocked(mode);
    final passed = c.passedModes.contains(mode);
    final best = c.bestScore[mode];

    final String status;
    final Color statusColor;
    if (locked) {
      final prev = idx > 0 ? kGameModes[kModeOrder[idx - 1]]!.title : '';
      status = '🔒 Önce "$prev" bölümünü geç';
      statusColor = AppColors.inkMuted;
    } else if (passed) {
      status = best == null ? '✓ Geçildi' : '✓ Geçildi · Rekor: ${_fmtBest(best)}';
      statusColor = const Color(0xFF1F7A3E);
    } else {
      status = '🎯 Hedef: ${def.failHint}';
      statusColor = def.ink;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.86),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: locked ? const [Color(0xFFE3E5F0), Color(0xFFA9AECB)] : def.accent,
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Opacity(opacity: locked ? 0.4 : 1, child: ModeGlyph(mode: mode, size: 38)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BÖLÜM ${idx + 1} · DÜNYA ${_worldOf(idx) + 1}',
                      style: baloo(10, FontWeight.w800, AppColors.inkPale, letterSpacing: 0.8),
                    ),
                    Text(def.title, style: baloo(20, FontWeight.w800, AppColors.ink, height: 1.1)),
                    Text(
                      def.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baloo(12, FontWeight.w600, AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: baloo(12, FontWeight.w700, statusColor),
            ),
          ),
          const SizedBox(height: 10),
          CandyButton(
            onTap: locked ? null : () => c.openMode(mode),
            height: 54,
            borderRadius: 18,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: locked ? const [Color(0xFFE3E5F0), Color(0xFFC3C7DC)] : def.accent,
            ),
            depthColor: locked ? const Color(0xFF9AA0BF) : def.depth,
            child: Text(
              locked ? '🔒 KİLİTLİ' : (passed ? 'TEKRAR OYNA' : 'OYNA ▶'),
              style: baloo(20, FontWeight.w800, locked ? AppColors.inkMuted : def.ink),
            ),
          ),
        ],
      ),
    );
  }
}
