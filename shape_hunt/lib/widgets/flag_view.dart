import 'package:flutter/material.dart';

import '../data/countries.dart';

/// Bir ulke kodunu basitlestirilmis bir bayrak kutusu olarak cizer.
class FlagView extends StatelessWidget {
  final String code;
  final double width;

  const FlagView({super.key, required this.code, this.width = 26});

  @override
  Widget build(BuildContext context) {
    final def = kCountries[code] ?? kCountries['TR']!;
    final height = width * 0.72;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x595A6496), width: 1),
      ),
      child: _buildFlag(def),
    );
  }

  Widget _buildFlag(CountryDef def) {
    switch (def.style) {
      case FlagStyle.solid:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: def.colors,
            ),
          ),
        );
      case FlagStyle.stripesH:
        final flexes = def.flexes ?? List.filled(def.colors.length, 1);
        return Column(
          children: [
            for (var i = 0; i < def.colors.length; i++)
              Expanded(flex: flexes[i], child: Container(color: def.colors[i])),
          ],
        );
      case FlagStyle.stripesV:
        return Row(
          children: [
            for (final c in def.colors) Expanded(child: Container(color: c)),
          ],
        );
      case FlagStyle.stripesHRepeat:
        return Column(
          children: List.generate(
            6,
            (i) => Expanded(child: Container(color: i.isEven ? def.colors[0] : def.colors[1])),
          ),
        );
      case FlagStyle.circleOnWhite:
        return Container(
          color: Colors.white,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.55,
              heightFactor: 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: def.colors[0], shape: BoxShape.circle),
              ),
            ),
          ),
        );
    }
  }
}
