import 'package:flutter/material.dart';

import 'audio/audio_manager.dart';
import 'controllers/game_controller.dart';
import 'models/game_enums.dart';
import 'models/game_mode.dart';
import 'screens/ad_offer_dialog.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/modes/aim_target_screen.dart';
import 'screens/modes/arrow_storm_screen.dart';
import 'screens/modes/basket_catch_screen.dart';
import 'screens/modes/bridge_builder_screen.dart';
import 'screens/modes/bubble_screen.dart';
import 'screens/modes/color_trap_screen.dart';
import 'screens/modes/cup_shuffle_screen.dart';
import 'screens/modes/dot_count_screen.dart';
import 'screens/modes/echo_sequence_screen.dart';
import 'screens/modes/finger_dodge_screen.dart';
import 'screens/modes/fruit_slice_screen.dart';
import 'screens/modes/go_no_go_screen.dart';
import 'screens/modes/keep_up_screen.dart';
import 'screens/modes/lane_runner_screen.dart';
import 'screens/modes/memory_cards_screen.dart';
import 'screens/modes/meteor_defense_screen.dart';
import 'screens/modes/mirror_trap_screen.dart';
import 'screens/modes/needle_screen.dart';
import 'screens/modes/neon_tunnel_screen.dart';
import 'screens/modes/number_hunt_screen.dart';
import 'screens/modes/odd_one_screen.dart';
import 'screens/modes/pole_balance_screen.dart';
import 'screens/modes/quick_math_screen.dart';
import 'screens/modes/ring_timing_screen.dart';
import 'screens/modes/samurai_duel_screen.dart';
import 'screens/modes/sort_belt_screen.dart';
import 'screens/modes/tile_rush_screen.dart';
import 'screens/modes/tower_stack_screen.dart';
import 'screens/modes/typing_screen.dart';
import 'screens/modes/whack_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/quit_dialog.dart';
import 'screens/signup_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/candy_button.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late final GameController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = GameController();
    controller.startLogoCycle();
  }

  /// Uygulama arka plana alininca (ekran kapanma, baska uygulamaya gecme)
  /// muzigi duraklat; geri donunce devam ettir. Aksi halde oyun kapali
  /// gorunurken arkada muzik calmaya devam ediyordu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        AudioManager.instance.pauseForBackground();
        controller.onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        AudioManager.instance.resumeFromBackground();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  /// Secili mini bolumun ekranini uretir.
  ///
  /// ValueKey onemli: bolum degistiginde Flutter'in eski bolumun State'ini
  /// (ve icindeki controller/zamanlayicilari) yeniden kullanmasini engeller.
  Widget _miniScreen() {
    switch (controller.activeMode) {
      case GameMode.oddOne:
        return OddOneScreen(key: const ValueKey('mini_odd'), app: controller);
      case GameMode.goNoGo:
        return GoNoGoScreen(key: const ValueKey('mini_gonogo'), app: controller);
      case GameMode.whack:
        return WhackScreen(key: const ValueKey('mini_whack'), app: controller);
      case GameMode.typing:
        return TypingScreen(key: const ValueKey('mini_typing'), app: controller);
      case GameMode.needle:
        return NeedleScreen(key: const ValueKey('mini_needle'), app: controller);
      case GameMode.bubble:
        return BubbleScreen(key: const ValueKey('mini_bubble'), app: controller);
      case GameMode.numberHunt:
        return NumberHuntScreen(key: const ValueKey('mini_number'), app: controller);
      case GameMode.colorTrap:
        return ColorTrapScreen(key: const ValueKey('mini_colortrap'), app: controller);
      case GameMode.arrowStorm:
        return ArrowStormScreen(key: const ValueKey('mini_arrows'), app: controller);
      case GameMode.fruitSlice:
        return FruitSliceScreen(key: const ValueKey('mini_fruit'), app: controller);
      case GameMode.aimTarget:
        return AimTargetScreen(key: const ValueKey('mini_aim'), app: controller);
      case GameMode.quickMath:
        return QuickMathScreen(key: const ValueKey('mini_math'), app: controller);
      case GameMode.ringTiming:
        return RingTimingScreen(key: const ValueKey('mini_ring'), app: controller);
      case GameMode.memoryCards:
        return MemoryCardsScreen(key: const ValueKey('mini_memory'), app: controller);
      case GameMode.laneRunner:
        return LaneRunnerScreen(key: const ValueKey('mini_lane'), app: controller);
      case GameMode.dotCount:
        return DotCountScreen(key: const ValueKey('mini_dots'), app: controller);
      case GameMode.basketCatch:
        return BasketCatchScreen(key: const ValueKey('mini_basket'), app: controller);
      case GameMode.cupShuffle:
        return CupShuffleScreen(key: const ValueKey('mini_cups'), app: controller);
      case GameMode.fingerDodge:
        return FingerDodgeScreen(key: const ValueKey('mini_dodge'), app: controller);
      case GameMode.keepUp:
        return KeepUpScreen(key: const ValueKey('mini_keepup'), app: controller);
      case GameMode.samuraiDuel:
        return SamuraiDuelScreen(key: const ValueKey('mini_samurai'), app: controller);
      case GameMode.towerStack:
        return TowerStackScreen(key: const ValueKey('mini_tower'), app: controller);
      case GameMode.bridgeBuilder:
        return BridgeBuilderScreen(key: const ValueKey('mini_bridge'), app: controller);
      case GameMode.poleBalance:
        return PoleBalanceScreen(key: const ValueKey('mini_pole'), app: controller);
      case GameMode.tileRush:
        return TileRushScreen(key: const ValueKey('mini_tiles'), app: controller);
      case GameMode.neonTunnel:
        return NeonTunnelScreen(key: const ValueKey('mini_neon'), app: controller);
      case GameMode.mirrorTrap:
        return MirrorTrapScreen(key: const ValueKey('mini_mirror'), app: controller);
      case GameMode.echoSequence:
        return EchoSequenceScreen(key: const ValueKey('mini_echo'), app: controller);
      case GameMode.meteorDefense:
        return MeteorDefenseScreen(key: const ValueKey('mini_meteor'), app: controller);
      case GameMode.sortBelt:
        return SortBeltScreen(key: const ValueKey('mini_belt'), app: controller);
      case GameMode.shapeHunt:
        // Sekil Avi mini akista degil, kendi tam ekraninda calisir.
        return GameScreen(controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        Widget screen;
        switch (controller.screen) {
          case AppScreen.signup:
            screen = SignupScreen(controller: controller);
            break;
          case AppScreen.home:
            screen = HomeScreen(controller: controller);
            break;
          case AppScreen.modes:
            screen = ModesScreen(controller: controller);
            break;
          case AppScreen.game:
            screen = GameScreen(controller: controller);
            break;
          case AppScreen.mini:
            screen = _miniScreen();
            break;
          case AppScreen.board:
            screen = LeaderboardScreen(controller: controller);
            break;
        }

        final s = controller.screen;
        final String? bgImage;
        if (s == AppScreen.signup) {
          bgImage = 'assets/images/signup_background.jpg';
        } else {
          // Diger tum ekranlar (ana menu, bolumler, oyun, siralama) ayni
          // manzara arka planini paylasir.
          bgImage = 'assets/images/game_background.jpg';
        }

        return Scaffold(
          // Klavye acildiginda govde kuculsun ki Hizli Klavye bolumundeki
          // giris kutusu klavyenin altinda kalmasin (Flutter odaklanan
          // alani otomatik gorunur hale getirir).
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: bgImage == null ? AppGradients.background : null,
              image: bgImage != null
                  ? DecorationImage(image: AssetImage(bgImage), fit: BoxFit.cover)
                  : null,
            ),
            child: Stack(
              children: [
                if (bgImage != null)
                  Positioned.fill(
                    child: Container(color: Colors.white.withOpacity(0.22)),
                  ),
                SafeArea(
                  child: Stack(
                    children: [
                      screen,
                      if (controller.confirmQuitOpen) QuitDialog(controller: controller),
                      if (controller.lockedNoticeMode != null)
                        _LockedNotice(controller: controller),
                      if (controller.adOfferOpen) AdOfferDialog(controller: controller),
                      if (controller.rewardNotice != null)
                        IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, -0.55),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                                gradient: AppGradients.gold,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Text(
                                controller.rewardNotice!,
                                style: baloo(17, FontWeight.w800, AppColors.goldInk),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kilitli bir bolume dokununca cikan bilgilendirme modali.
class _LockedNotice extends StatelessWidget {
  final GameController controller;
  const _LockedNotice({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: controller.dismissLockedNotice,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: const Color(0x80787EC3),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.82)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD7DAEC), Color(0xFFB9BEDA)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_rounded, size: 32, color: Color(0xFF6E739E)),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bu bölüm kilitli',
                  style: baloo(22, FontWeight.w800, AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu bölümün açılması için önce kendinden önceki bölümü başarıyla geçmelisin.',
                  textAlign: TextAlign.center,
                  style: baloo(13, FontWeight.w600, AppColors.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 18),
                CandyButton(
                  onTap: controller.dismissLockedNotice,
                  height: 52,
                  borderRadius: 18,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
                  ),
                  depthColor: const Color(0xFF5FA22A),
                  child: Text('Anladım', style: baloo(18, FontWeight.w800, AppColors.greenInk)),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: controller.dismissLockedNotice,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    child: Text('Kapat', style: baloo(15, FontWeight.w700, AppColors.inkMuted)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
