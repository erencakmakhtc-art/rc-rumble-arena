import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DominoBayrakApp());
}

class DominoBayrakApp extends StatelessWidget {
  const DominoBayrakApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RC Rumble Arena',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff42d7f3))),
        home: const GameScreen(),
      );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff0a111b))
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (error) {
          // A network error in an optional remote font should not cover the game.
          if (error.isForMainFrame == true && mounted) {
            setState(() => _loadError = error.description);
          }
        },
        onPageFinished: (_) {
          if (mounted && _loadError != null) setState(() => _loadError = null);
        },
      ))
      ..loadFlutterAsset('assets/games/domino_bayrak.html');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0a111b),
        body: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: _controller),
            if (_loadError != null)
              ColoredBox(
                color: const Color(0xff182034),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 42),
                        const SizedBox(height: 12),
                        const Text('Oyun yüklenemedi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 20),
                        FilledButton(onPressed: () { setState(() => _loadError = null); _controller.reload(); }, child: const Text('Tekrar dene')),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
