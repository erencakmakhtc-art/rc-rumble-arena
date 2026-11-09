import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_mode.dart';

/// Bolum menusunde ve bolum basliklarinda kullanilan, her mod icin ozel
/// cizilmis ikon. Disaridan gorsel dosyasi gerektirmez; uygulamanin parlak
/// "seker" gorsel diliyle uyumlu olacak sekilde elle cizilir.
class ModeGlyph extends StatelessWidget {
  final GameMode mode;
  final double size;

  const ModeGlyph({super.key, required this.mode, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ModeGlyphPainter(mode)),
    );
  }
}

class _ModeGlyphPainter extends CustomPainter {
  final GameMode mode;
  _ModeGlyphPainter(this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (mode) {
      case GameMode.shapeHunt:
        _shapeHunt(canvas, w, h);
        break;
      case GameMode.oddOne:
        _oddOne(canvas, w, h);
        break;
      case GameMode.goNoGo:
        _goNoGo(canvas, w, h);
        break;
      case GameMode.whack:
        _whack(canvas, w, h);
        break;
      case GameMode.typing:
        _typing(canvas, w, h);
        break;
      case GameMode.needle:
        _needle(canvas, w, h);
        break;
      case GameMode.bubble:
        _bubble(canvas, w, h);
        break;
      case GameMode.numberHunt:
        _numberHunt(canvas, w, h);
        break;
      case GameMode.colorTrap:
        _colorTrap(canvas, w, h);
        break;
      case GameMode.arrowStorm:
        _arrowStorm(canvas, w, h);
        break;
      case GameMode.fruitSlice:
        _gFruitSlice(canvas, w, h);
        break;
      case GameMode.aimTarget:
        _gAimTarget(canvas, w, h);
        break;
      case GameMode.quickMath:
        _gQuickMath(canvas, w, h);
        break;
      case GameMode.ringTiming:
        _gRingTiming(canvas, w, h);
        break;
      case GameMode.memoryCards:
        _gMemoryCards(canvas, w, h);
        break;
      case GameMode.laneRunner:
        _gLaneRunner(canvas, w, h);
        break;
      case GameMode.dotCount:
        _gDotCount(canvas, w, h);
        break;
      case GameMode.basketCatch:
        _gBasketCatch(canvas, w, h);
        break;
      case GameMode.cupShuffle:
        _gCupShuffle(canvas, w, h);
        break;
      case GameMode.fingerDodge:
        _gFingerDodge(canvas, w, h);
        break;
      case GameMode.keepUp:
        _gKeepUp(canvas, w, h);
        break;
      case GameMode.samuraiDuel:
        _gSamuraiDuel(canvas, w, h);
        break;
      case GameMode.towerStack:
        _gTowerStack(canvas, w, h);
        break;
      case GameMode.bridgeBuilder:
        _gBridgeBuilder(canvas, w, h);
        break;
      case GameMode.poleBalance:
        _gPoleBalance(canvas, w, h);
        break;
      case GameMode.tileRush:
        _gTileRush(canvas, w, h);
        break;
      case GameMode.neonTunnel:
        _gNeonTunnel(canvas, w, h);
        break;
      case GameMode.mirrorTrap:
        _gMirrorTrap(canvas, w, h);
        break;
      case GameMode.echoSequence:
        _gEchoSequence(canvas, w, h);
        break;
      case GameMode.meteorDefense:
        _gMeteorDefense(canvas, w, h);
        break;
      case GameMode.sortBelt:
        _gSortBelt(canvas, w, h);
        break;
    }
  }

  // ---- ortak yardimcilar -------------------------------------------------

  Paint _fill(Color top, Color bottom, Rect r) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(r);
  }

  void _gloss(Canvas canvas, Rect r, {double heightFactor = 0.34}) {
    final hl = Rect.fromLTWH(
      r.left + r.width * 0.16,
      r.top + r.height * 0.08,
      r.width * 0.68,
      r.height * heightFactor,
    );
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.0)],
      ).createShader(hl);
    canvas.drawOval(hl, p);
  }

  void _roundedShape(Canvas canvas, Rect r, double radius, Color top, Color bottom) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, _fill(top, bottom, r));
    canvas.save();
    canvas.clipRRect(rr);
    _gloss(canvas, r);
    canvas.restore();
  }

  void _circle(Canvas canvas, Offset c, double radius, Color top, Color bottom) {
    final r = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(c, radius, _fill(top, bottom, r));
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    _gloss(canvas, r);
    canvas.restore();
  }

  void _triangle(Canvas canvas, Rect r, Color top, Color bottom) {
    final path = Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();
    canvas.drawPath(path, _fill(top, bottom, r));
    canvas.save();
    canvas.clipPath(path);
    _gloss(canvas, r, heightFactor: 0.4);
    canvas.restore();
  }

  // ---- mod ikonlari ------------------------------------------------------

  /// Buyutec altinda bir ucgen: "sekil arama".
  void _shapeHunt(Canvas canvas, double w, double h) {
    _triangle(
      canvas,
      Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.58, h * 0.56),
      const Color(0xFFFFC98A),
      const Color(0xFFF07A1F),
    );
    // buyutec halkasi
    final c = Offset(w * 0.62, h * 0.58);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..color = const Color(0xFF5B62A8);
    canvas.drawCircle(c, w * 0.26, ring);
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5B62A8);
    canvas.drawLine(
      Offset(c.dx + w * 0.19, c.dy + h * 0.19),
      Offset(w * 0.93, h * 0.93),
      handle,
    );
  }

  /// Uc daire, biri soluk: "farkli olani bul".
  void _oddOne(Canvas canvas, double w, double h) {
    final r = w * 0.16;
    _circle(canvas, Offset(w * 0.26, h * 0.3), r, const Color(0xFFFFB3D8), const Color(0xFFE8559C));
    _circle(canvas, Offset(w * 0.72, h * 0.3), r, const Color(0xFFFFB3D8), const Color(0xFFE8559C));
    _circle(canvas, Offset(w * 0.26, h * 0.74), r, const Color(0xFFFFB3D8), const Color(0xFFE8559C));
    // farkli olan: soluk ton + vurgu halkasi
    _circle(canvas, Offset(w * 0.72, h * 0.74), r, const Color(0xFFFFE2F0), const Color(0xFFF7A8CC));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..color = const Color(0xFF8A2E5C);
    canvas.drawCircle(Offset(w * 0.72, h * 0.74), r + w * 0.07, ring);
  }

  /// Ustte yesil, altta kirmizi lamba: "git / dur".
  void _goNoGo(Canvas canvas, double w, double h) {
    _roundedShape(
      canvas,
      Rect.fromLTWH(w * 0.24, h * 0.06, w * 0.52, h * 0.88),
      w * 0.18,
      const Color(0xFF9AA2D8),
      const Color(0xFF5E68AE),
    );
    _circle(canvas, Offset(w * 0.5, h * 0.31), w * 0.17, const Color(0xFFC9F79E), const Color(0xFF6FC22A));
    _circle(canvas, Offset(w * 0.5, h * 0.69), w * 0.17, const Color(0xFFFFB3B3), const Color(0xFFE24B4B));
  }

  /// Delikten cikan kostebek kafasi.
  void _whack(Canvas canvas, double w, double h) {
    // kostebek
    _circle(canvas, Offset(w * 0.5, h * 0.46), w * 0.28, const Color(0xFFFFD79E), const Color(0xFFD98A2B));
    // gozler
    final eye = Paint()..color = const Color(0xFF6B3A05);
    canvas.drawCircle(Offset(w * 0.41, h * 0.42), w * 0.045, eye);
    canvas.drawCircle(Offset(w * 0.59, h * 0.42), w * 0.045, eye);
    // delik (on plan)
    final holeRect = Rect.fromLTWH(w * 0.08, h * 0.62, w * 0.84, h * 0.3);
    final hole = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF7A5327), Color(0xFF4A3013)],
      ).createShader(holeRect);
    canvas.drawOval(holeRect, hole);
  }

  /// Klavye tuslari.
  void _typing(Canvas canvas, double w, double h) {
    _roundedShape(
      canvas,
      Rect.fromLTWH(w * 0.05, h * 0.24, w * 0.9, h * 0.54),
      w * 0.12,
      const Color(0xFFDCD6FA),
      const Color(0xFF9A8BE0),
    );
    final key = Paint()..color = Colors.white.withOpacity(0.92);
    const cols = 4;
    final kw = w * 0.15;
    final kh = h * 0.1;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < cols; col++) {
        final x = w * 0.13 + col * (kw + w * 0.05);
        final y = h * 0.34 + row * (kh + h * 0.07);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, kw, kh), Radius.circular(w * 0.035)),
          key,
        );
      }
    }
    // uzun bosluk tusu
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.62, w * 0.44, h * 0.09),
        Radius.circular(w * 0.035),
      ),
      key,
    );
  }

  /// Yarim daire kadran + ibre.
  void _needle(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.5, h * 0.78);
    final radius = w * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFBFE6DA);
    canvas.drawArc(rect, pi, pi, false, track);

    // hedef bolge (ortada yesil dilim)
    final zone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFF3FBF97);
    canvas.drawArc(rect, pi * 1.4, pi * 0.2, false, zone);

    // ibre
    final needle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF13624A);
    final angle = pi * 1.32;
    canvas.drawLine(
      center,
      Offset(center.dx + cos(angle) * radius * 0.94, center.dy + sin(angle) * radius * 0.94),
      needle,
    );
    _circle(canvas, center, w * 0.085, const Color(0xFFFFFFFF), const Color(0xFFBFE6DA));
  }

  /// Farkli boyutlarda uc parlak baloncuk.
  void _bubble(Canvas canvas, double w, double h) {
    _bubbleDot(canvas, Offset(w * 0.38, h * 0.6), w * 0.3);
    _bubbleDot(canvas, Offset(w * 0.76, h * 0.3), w * 0.17);
    _bubbleDot(canvas, Offset(w * 0.8, h * 0.74), w * 0.1);
  }

  void _bubbleDot(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFFFFFF), Color(0xFFBDEBFF), Color(0xFF5CC6EE)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0xFF1F86B3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-r * 0.35, -r * 0.4), width: r * 0.5, height: r * 0.3),
      Paint()..color = Colors.white.withOpacity(0.95),
    );
  }

  /// Ortalanmis kalin yazi (sayi/harf ikonlari icin).
  void _text(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Baloo2',
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontVariations: [FontVariation('wght', 800)],
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  /// 2x2 sayi karolari: "sirayla bul".
  void _numberHunt(Canvas canvas, double w, double h) {
    final tile = w * 0.42;
    final gap = w * 0.06;
    const labels = ['1', '2', '3', '4'];
    const inks = [Color(0xFF6B5200), Color(0xFFD9437F), Color(0xFF1E7FC0), Color(0xFF2B9453)];
    for (var i = 0; i < 4; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final r = Rect.fromLTWH(w * 0.05 + col * (tile + gap), h * 0.05 + row * (tile + gap), tile, tile);
      if (i == 0) {
        _roundedShape(canvas, r, w * 0.1, const Color(0xFFFFF3B0), const Color(0xFFF5C518));
      } else {
        _roundedShape(canvas, r, w * 0.1, const Color(0xFFFFFFFF), const Color(0xFFE6E9FA));
      }
      _text(canvas, labels[i], r.center, tile * 0.62, inks[i]);
    }
  }

  /// Mavi karo uzerinde kirmizi harf: "renk/anlam catismasi".
  void _colorTrap(Canvas canvas, double w, double h) {
    final r = Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.84, h * 0.76);
    _roundedShape(canvas, r, w * 0.2, const Color(0xFFA9C8FF), const Color(0xFF3F7BE6));
    _text(canvas, 'Aa', r.center + Offset(0, h * 0.02), w * 0.44, const Color(0xFFFF4B4B));
  }

  void _arrowPath(Canvas canvas, Offset c, double s, double angle, Color top, Color bottom) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -0.46 * s)
      ..lineTo(0.44 * s, 0)
      ..lineTo(0.17 * s, 0)
      ..lineTo(0.17 * s, 0.44 * s)
      ..lineTo(-0.17 * s, 0.44 * s)
      ..lineTo(-0.17 * s, 0)
      ..lineTo(-0.44 * s, 0)
      ..close();
    final rect = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    canvas.drawPath(path, _fill(top, bottom, rect));
    canvas.restore();
  }

  /// Sola bakan iki mavi ok arasinda saga bakan kirmizi ok: "yaniltici yan oklar".
  void _arrowStorm(Canvas canvas, double w, double h) {
    final s = w * 0.36;
    _arrowPath(canvas, Offset(w * 0.18, h * 0.5), s, -pi / 2, const Color(0xFF9AA8F5), const Color(0xFF3656C4));
    _arrowPath(canvas, Offset(w * 0.82, h * 0.5), s, -pi / 2, const Color(0xFF9AA8F5), const Color(0xFF3656C4));
    _arrowPath(canvas, Offset(w * 0.5, h * 0.5), s * 1.08, pi / 2, const Color(0xFFFF9A9A), const Color(0xFFE02F2F));
  }

  // ---- Yeni bolum ikonlari ----

  /// Ikiye bolunmus elma.
  void _gFruitSlice(Canvas canvas, double w, double h) {
    final c = Offset(w * 0.5, h * 0.55);
    final r = w * 0.34;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, c.dy - 2));
    canvas.translate(-w * 0.05, -h * 0.04);
    _circle(canvas, c, r, const Color(0xFFFF8A80), const Color(0xFFD32F2F));
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, c.dy + 2, w, h));
    canvas.translate(w * 0.05, h * 0.04);
    _circle(canvas, c, r, const Color(0xFFFF8A80), const Color(0xFFD32F2F));
    canvas.restore();
    canvas.drawLine(
      Offset(w * 0.06, c.dy),
      Offset(w * 0.94, c.dy),
      Paint()
        ..color = Colors.white
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Nisan tahtasi.
  void _gAimTarget(Canvas canvas, double w, double h) {
    final c = Offset(w / 2, h / 2);
    const colors = [Color(0xFFE53935), Color(0xFFFFFFFF), Color(0xFFE53935), Color(0xFFFFFFFF)];
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(c, w * 0.42 * (1 - i * 0.24), Paint()..color = colors[i]);
    }
    canvas.drawCircle(c, w * 0.06, Paint()..color = const Color(0xFFB71C1C));
  }

  /// "7x8" karosu.
  void _gQuickMath(Canvas canvas, double w, double h) {
    final r = Rect.fromLTWH(w * 0.06, h * 0.14, w * 0.88, h * 0.72);
    _roundedShape(canvas, r, w * 0.18, const Color(0xFFBDE4FF), const Color(0xFF1F78B3));
    _text(canvas, '7×8', r.center, w * 0.34, Colors.white);
  }

  /// Hedef daire + daralan halka.
  void _gRingTiming(Canvas canvas, double w, double h) {
    final c = Offset(w / 2, h / 2);
    _circle(canvas, c, w * 0.24, const Color(0xFFFFB3D8), const Color(0xFFE8559C));
    canvas.drawCircle(
      c,
      w * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..color = const Color(0xFF8C92E6),
    );
  }

  /// Biri acik biri kapali iki kart.
  void _gMemoryCards(Canvas canvas, double w, double h) {
    final back = Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.5, h * 0.66);
    _roundedShape(canvas, back, w * 0.08, const Color(0xFF7C84D4), const Color(0xFF3F4478));
    _text(canvas, '?', back.center, w * 0.3, Colors.white);
    final front = Rect.fromLTWH(w * 0.42, h * 0.24, w * 0.5, h * 0.66);
    _roundedShape(canvas, front, w * 0.08, const Color(0xFFFFFFFF), const Color(0xFFE6E9FA));
    _circle(canvas, front.center, w * 0.13, const Color(0xFFBFE0FF), const Color(0xFF1257C4));
  }

  /// Uc serit + kosucu top.
  void _gLaneRunner(Canvas canvas, double w, double h) {
    final road = Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.84, h * 0.88);
    _roundedShape(canvas, road, w * 0.14, const Color(0xFF7A80B8), const Color(0xFF4D5288));
    final dash = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    for (final x in [w * 0.36, w * 0.64]) {
      canvas.drawLine(Offset(x, h * 0.16), Offset(x, h * 0.34), dash);
      canvas.drawLine(Offset(x, h * 0.5), Offset(x, h * 0.68), dash);
    }
    _circle(canvas, Offset(w * 0.5, h * 0.76), w * 0.11, const Color(0xFFFFE082), const Color(0xFFFFA000));
  }

  /// Zar gibi dizilmis bes nokta.
  void _gDotCount(Canvas canvas, double w, double h) {
    final r = Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84);
    _roundedShape(canvas, r, w * 0.18, const Color(0xFFFFFFFF), const Color(0xFFFFE7B8));
    final dot = Paint()..color = const Color(0xFF5E3C00);
    for (final p in const [Offset(0.3, 0.3), Offset(0.7, 0.3), Offset(0.5, 0.5), Offset(0.3, 0.7), Offset(0.7, 0.7)]) {
      canvas.drawCircle(Offset(w * p.dx, h * p.dy), w * 0.075, dot);
    }
  }

  /// Sepet + dusen portakal.
  void _gBasketCatch(Canvas canvas, double w, double h) {
    _circle(canvas, Offset(w * 0.5, h * 0.26), w * 0.15, const Color(0xFFFFCC80), const Color(0xFFF57C00));
    final path = Path()
      ..moveTo(w * 0.12, h * 0.52)
      ..lineTo(w * 0.88, h * 0.52)
      ..lineTo(w * 0.74, h * 0.9)
      ..lineTo(w * 0.26, h * 0.9)
      ..close();
    canvas.drawPath(path, _fill(const Color(0xFFD7A15E), const Color(0xFF9C6A2E), Rect.fromLTWH(0, h * 0.52, w, h * 0.38)));
  }

  /// Kirmizi ters bardak ve top.
  void _gCupShuffle(Canvas canvas, double w, double h) {
    _circle(canvas, Offset(w * 0.8, h * 0.8), w * 0.1, const Color(0xFFFFF3B0), const Color(0xFFFFB300));
    final path = Path()
      ..moveTo(w * 0.3, h * 0.14)
      ..lineTo(w * 0.58, h * 0.14)
      ..lineTo(w * 0.72, h * 0.88)
      ..lineTo(w * 0.16, h * 0.88)
      ..close();
    canvas.drawPath(path, _fill(const Color(0xFFFF8A80), const Color(0xFFB71C1C), Rect.fromLTWH(0, 0, w, h)));
  }

  /// Parmak halkasi ve etrafindaki toplar.
  void _gFingerDodge(Canvas canvas, double w, double h) {
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.52),
      w * 0.16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..color = const Color(0xFF3A1F80),
    );
    _circle(canvas, Offset(w * 0.18, h * 0.2), w * 0.12, const Color(0xFFFF9A9A), const Color(0xFFD9303A));
    _circle(canvas, Offset(w * 0.84, h * 0.3), w * 0.1, const Color(0xFFFF9A9A), const Color(0xFFD9303A));
    _circle(canvas, Offset(w * 0.3, h * 0.86), w * 0.1, const Color(0xFFC9A7FF), const Color(0xFF6A3FD0));
  }

  /// Havadaki top ve hareket cizgileri.
  void _gKeepUp(Canvas canvas, double w, double h) {
    _circle(canvas, Offset(w * 0.5, h * 0.36), w * 0.26, const Color(0xFF9AD0FF), const Color(0xFF2E78D0));
    final line = Paint()
      ..color = const Color(0xFFD1612A)
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    for (final x in [0.36, 0.5, 0.64]) {
      canvas.drawLine(Offset(w * x, h * 0.72), Offset(w * x, h * 0.9), line);
    }
  }

  // ---- 3. dalga bolum ikonlari ----

  /// Gun batimi gunesi onunde katana.
  void _gSamuraiDuel(Canvas canvas, double w, double h) {
    _circle(canvas, Offset(w * 0.5, h * 0.5), w * 0.38, const Color(0xFFFFE08A), const Color(0xFFE0668A));
    canvas.drawLine(
      Offset(w * 0.2, h * 0.8),
      Offset(w * 0.84, h * 0.18),
      Paint()
        ..color = const Color(0xFFF4F6FF)
        ..strokeWidth = w * 0.06
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.14, h * 0.86),
      Offset(w * 0.3, h * 0.7),
      Paint()
        ..color = const Color(0xFF1B1530)
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Kaydirilmis ust uste bloklar.
  void _gTowerStack(Canvas canvas, double w, double h) {
    const hues = [200.0, 228.0, 256.0, 284.0];
    const offs = [0.0, 0.06, -0.04, 0.08];
    for (var i = 0; i < 4; i++) {
      final bw = w * (0.8 - i * 0.1);
      final r = Rect.fromLTWH((w - bw) / 2 + w * offs[i], h * (0.74 - i * 0.2), bw, h * 0.18);
      final c = HSVColor.fromAHSV(1, hues[i], 0.5, 0.95).toColor();
      final d = HSVColor.fromAHSV(1, hues[i], 0.55, 0.75).toColor();
      _roundedShape(canvas, r, w * 0.05, c, d);
    }
  }

  /// Iki sutun arasinda cubuk kopru ve kahraman.
  void _gBridgeBuilder(Canvas canvas, double w, double h) {
    final dark = _fill(const Color(0xFF4D5288), const Color(0xFF23264F), Rect.fromLTWH(0, h * 0.55, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(w * 0.02, h * 0.55, w * 0.26, h * 0.45), dark);
    canvas.drawRect(Rect.fromLTWH(w * 0.74, h * 0.55, w * 0.22, h * 0.45), dark);
    canvas.drawLine(
      Offset(w * 0.28, h * 0.555),
      Offset(w * 0.8, h * 0.555),
      Paint()
        ..color = const Color(0xFF5A3A22)
        ..strokeWidth = w * 0.05,
    );
    _circle(canvas, Offset(w * 0.16, h * 0.42), w * 0.11, const Color(0xFFFFE082), const Color(0xFFFFA000));
  }

  /// Araba uzerinde egik seritli cubuk.
  void _gPoleBalance(Canvas canvas, double w, double h) {
    canvas.save();
    canvas.translate(w * 0.5, h * 0.8);
    canvas.rotate(0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.05, -h * 0.66, w * 0.1, h * 0.66), Radius.circular(w * 0.05)),
      Paint()..color = const Color(0xFFE8559C),
    );
    _circle(canvas, Offset(0, -h * 0.66), w * 0.1, const Color(0xFFFFF1A8), const Color(0xFFE0A800));
    canvas.restore();
    _roundedShape(canvas, Rect.fromLTWH(w * 0.24, h * 0.78, w * 0.52, h * 0.14), w * 0.06,
        const Color(0xFFFF6B6B), const Color(0xFFB71C1C));
  }

  /// Dort kolon, iki koyu tus.
  void _gTileRush(Canvas canvas, double w, double h) {
    final bg = Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.88);
    _roundedShape(canvas, bg, w * 0.12, const Color(0xFFFFFFFF), const Color(0xFFE6E9FA));
    final cw = bg.width / 4;
    final dark = _fill(const Color(0xFF4D5288), const Color(0xFF1C1F3F), bg);
    canvas.drawRect(Rect.fromLTWH(bg.left + cw * 1 + 2, bg.top + 4, cw - 4, bg.height * 0.42), dark);
    canvas.drawRect(Rect.fromLTWH(bg.left + cw * 3 + 2, bg.top + bg.height * 0.52, cw - 4, bg.height * 0.42), dark);
  }

  /// Karanlik zeminde iki neon dalga.
  void _gNeonTunnel(Canvas canvas, double w, double h) {
    final r = Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.92, h * 0.92);
    _roundedShape(canvas, r, w * 0.2, const Color(0xFF2A1459), const Color(0xFF120B2E));
    for (final (dx, color) in const [(-0.16, Color(0xFF3DF2FF)), (0.16, Color(0xFFFF4FD8))]) {
      final path = Path();
      for (var i = 0; i <= 12; i++) {
        final y = h * (0.12 + i * 0.065);
        final x = w * (0.5 + dx + 0.14 * sin(i * 0.8));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  /// L parcasi ve aynasi, arada kesikli eksen.
  void _gMirrorTrap(Canvas canvas, double w, double h) {
    final cell = w * 0.13;
    void piece(double ox, bool mirrored, Color a, Color b) {
      const cells = [(0, 0), (0, 1), (0, 2), (1, 2)];
      for (final (cx, cy) in cells) {
        final x = mirrored ? ox - (cx + 1) * cell : ox + cx * cell;
        _roundedShape(canvas, Rect.fromLTWH(x + 1, h * 0.28 + cy * cell + 1, cell - 2, cell - 2), cell * 0.25, a, b);
      }
    }
    piece(w * 0.12, false, const Color(0xFFFFB3D8), const Color(0xFFD9437F));
    piece(w * 0.88, true, const Color(0xFFDDDDEE), const Color(0xFF8C92B8));
    final dash = Paint()
      ..color = const Color(0xFF661840)
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    for (var y = h * 0.12; y < h * 0.9; y += h * 0.14) {
      canvas.drawLine(Offset(w * 0.5, y), Offset(w * 0.5, y + h * 0.07), dash);
    }
  }

  /// Dort renkli ceyrek disk.
  void _gEchoSequence(Canvas canvas, double w, double h) {
    const colors = [Color(0xFFFF5A5A), Color(0xFF4DA3FF), Color(0xFF5BD68A), Color(0xFFFFD24D)];
    final c = Offset(w / 2, h / 2);
    final rect = Rect.fromCircle(center: c, radius: w * 0.3);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        -pi / 2 + i * pi / 2 + 0.08,
        pi / 2 - 0.16,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.18
          ..color = colors[i],
      );
    }
  }

  /// Gezegen yayi ve kuyruklu meteor.
  void _gMeteorDefense(Canvas canvas, double w, double h) {
    _circle(canvas, Offset(w * 0.5, h * 1.25), w * 0.62, const Color(0xFF6FD3FF), const Color(0xFF1565C0));
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.62, h * 0.3)
        ..lineTo(w * 0.95, h * 0.02)
        ..lineTo(w * 0.72, h * 0.42)
        ..close(),
      Paint()..color = const Color(0xFFFFB74D),
    );
    _circle(canvas, Offset(w * 0.6, h * 0.42), w * 0.13, const Color(0xFFC9A28A), const Color(0xFF6B3F2A));
  }

  /// Bant ve yukari/asagi oklari.
  void _gSortBelt(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h * 0.4, w, h * 0.22), Paint()..color = const Color(0xFF4A4F6B));
    _circle(canvas, Offset(w * 0.3, h * 0.51), w * 0.09, const Color(0xFFFF8A80), const Color(0xFFC62828));
    _roundedShape(canvas, Rect.fromLTWH(w * 0.56, h * 0.43, w * 0.17, h * 0.17), w * 0.04,
        const Color(0xFF90C2FF), const Color(0xFF1250B8));
    final arrow = Paint()..color = const Color(0xFF2E3250);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.04)
        ..lineTo(w * 0.64, h * 0.26)
        ..lineTo(w * 0.36, h * 0.26)
        ..close(),
      arrow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.96)
        ..lineTo(w * 0.64, h * 0.74)
        ..lineTo(w * 0.36, h * 0.74)
        ..close(),
      arrow,
    );
  }

  @override
  bool shouldRepaint(covariant _ModeGlyphPainter oldDelegate) => oldDelegate.mode != mode;
}
