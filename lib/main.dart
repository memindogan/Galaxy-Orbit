/// Entry point for Neon Orbit.
///
/// Sets up [MultiProvider] with [SettingsProvider] and [GameStateProvider],
/// forces full-screen portrait mode, and launches [MainMenuScreen].
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/game_state_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_menu_screen.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure global audio context before any audio players are created
  await AudioService.configureGlobalContext();

  // Lock to portrait + hide system overlays for immersive experience.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const NeonOrbitApp());
}

class NeonOrbitApp extends StatelessWidget {
  const NeonOrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => GameStateProvider()),
      ],
      child: MaterialApp(
        title: 'Neon Orbit',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const MainMenuScreen(),
      ),
    );
  }
}
