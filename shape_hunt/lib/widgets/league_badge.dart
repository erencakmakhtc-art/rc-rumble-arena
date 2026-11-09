import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ana ekranda kullanicinin bulundugu ligi gosteren sik bir rozet.
///
/// Ligler global rank'e gore hesaplanir (bkz. GameController.leagueTier).
/// Her 200 kisi = 1 lig. 1. Lig en iyi 200 oyuncu, 2. Lig 201-400, ...
/// En son lig = yeni kayit + hicbir sey oynamamis oyuncularin baslangic ligi.
///
/// Widget herhangi bir [tier] numarasini (1..N) zarifce isler:
///   * 1        -> ELIT (altin prestij) - "1. Lig"
///   * 2..3     -> Gumus / Bronz
///   * 4..10    -> Cetin cevik (koyu metal)
///   * 11+      -> Notr (nazik mor-gri, oyuncularin cogunlugu icin)
class LeagueBadge extends StatelessWidget {
  /// 1..N. 1 = en iyi lig.
  final int tier;

  /// Global rank (kacinci siradasin). null ise alt etiket lig etiketi olur.
  final int? rank;

  /// Alt etiket gosterilsin mi? (varsayilan: true)
  final bool showSubLabel;

  const LeagueBadge({
    super.key,
    required this.tier,
    this.rank,
    this.showSubLabel = true,
  });

  /// 1234567 -> "1.234.567"
  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(tier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: s.gradient,
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
            boxShadow: [
              BoxShadow(
                color: s.shadow,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.medal,
                style: const TextStyle(fontSize: 18, height: 1.0),
              ),
              const SizedBox(width: 8),
              Text(
                '$tier. Lig',
                style: baloo(15, FontWeight.w800, s.textColor, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
        if (showSubLabel) ...[
          const SizedBox(height: 6),
          Text(
            rank != null ? '#${_fmt(rank!)}. sıradasın' : s.subLabel,
            style: baloo(11, FontWeight.w700, AppColors.inkFaint, letterSpacing: 0.4),
          ),
        ],
      ],
    );
  }
}

class _LeagueStyle {
  final LinearGradient gradient;
  final Color textColor;
  final Color shadow;
  final String medal;
  final String subLabel;

  const _LeagueStyle({
    required this.gradient,
    required this.textColor,
    required this.shadow,
    required this.medal,
    required this.subLabel,
  });
}

// -----------------------------------------------------------------------------
// Tier -> gorsel tema esleme.
// Cok yuksek tier numaralari (yeni oyuncular icin binlik/onbinlik) da notr
// gradyanla zarifce goruntulenir.
// -----------------------------------------------------------------------------

const _goldStyle = _LeagueStyle(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF3C4), Color(0xFFFFC842)],
  ),
  textColor: Color(0xFF7A4A00),
  shadow: Color(0x55C48A00),
  medal: '🥇',
  subLabel: 'ELİT LİG',
);

const _silverStyle = _LeagueStyle(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6F8FC), Color(0xFFB8C0D4)],
  ),
  textColor: Color(0xFF3F4478),
  shadow: Color(0x559098B8),
  medal: '🥈',
  subLabel: 'GÜMÜŞ LİG',
);

const _bronzeStyle = _LeagueStyle(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE0BC), Color(0xFFD98A45)],
  ),
  textColor: Color(0xFF5A2E00),
  shadow: Color(0x55A0521C),
  medal: '🥉',
  subLabel: 'BRONZ LİG',
);

const _ironStyle = _LeagueStyle(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE7EAF3), Color(0xFF8890AE)],
  ),
  textColor: Color(0xFF2C3055),
  shadow: Color(0x55575E82),
  medal: '🎖️',
  subLabel: 'DEMİR LİG',
);

const _neutralStyle = _LeagueStyle(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFECEEFB), Color(0xFFBFC5E8)],
  ),
  textColor: Color(0xFF4D5288),
  shadow: Color(0x448C92CD),
  medal: '🏅',
  subLabel: 'STANDART LİG',
);

_LeagueStyle _styleFor(int tier) {
  if (tier <= 1) return _goldStyle;
  if (tier == 2) return _silverStyle;
  if (tier == 3) return _bronzeStyle;
  if (tier <= 10) return _ironStyle;
  return _neutralStyle;
}
