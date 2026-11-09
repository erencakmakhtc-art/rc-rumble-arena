import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_root.dart';
import 'audio/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uygulamayi yalnizca dikey (portrait) modda calistir - yatay mod kapali.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Kisa efektleri onceden yukle ki ilk calmada gecikme olmasin.
  // await ediyoruz: aksi halde runApp ile cakisip bazi player'lar
  // yuklenemiyor ve efektler sessizce devre disi kaliyor.
  await AudioManager.instance.warmUp();
  runApp(const ShapeHuntApp());
}

class ShapeHuntApp extends StatelessWidget {
  const ShapeHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reflex World League',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFC9CDF0),
      ),
      home: const AppRoot(),
    );
  }
}