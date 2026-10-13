import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_orbit/main.dart';
import 'package:neon_orbit/providers/settings_provider.dart';
import 'package:neon_orbit/screens/game_modals.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NeonOrbitApp());
    expect(find.text('GALAXY'), findsOneWidget);
    expect(find.text('ORBIT'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('Navigating to Hangar screen opens celestial market',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NeonOrbitApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the Hangar button
    final hangarButton = find.byKey(const Key('menu_hangar_button'));
    expect(hangarButton, findsOneWidget);
    await tester.tap(hangarButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Hangar UI elements
    expect(find.text('CELESTIAL MARKET'), findsOneWidget);
    expect(find.text('Your cosmic fleet'), findsOneWidget);
    expect(find.text('Worlds & companions'), findsOneWidget);
  });

  testWidgets('Equipping Ember in Hangar updates Main Menu caption',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NeonOrbitApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Initially Main Menu shows Terra caption
    expect(find.text('TERRA  •  LUNA COMPANION'), findsOneWidget);

    // Open Hangar
    final hangarButton = find.byKey(const Key('menu_hangar_button'));
    await tester.tap(hangarButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Ember world card (Ember is unlocked by default)
    final emberCard = find.text('Ember');
    expect(emberCard, findsOneWidget);
    await tester.tap(emberCard.first);
    await tester.pump(const Duration(milliseconds: 200));

    // Tap Equip on Ember card
    final equipButton = find.text('Equip');
    expect(equipButton, findsOneWidget);
    await tester.ensureVisible(equipButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(equipButton);
    await tester.pump(const Duration(milliseconds: 200));

    // Pop back to Main Menu via back button
    final backButton = find.byKey(const Key('hangar_back_button'));
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Main Menu should now show EMBER & SCOUT-7 COMPANION
    expect(find.text('EMBER  •  SCOUT-7 COMPANION'), findsOneWidget);

    // Tap PLAY button to launch the game
    final playButton = find.text('PLAY');
    await tester.tap(playButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify In-Game HUD displays SCOUT-7 badge
    expect(find.text('SCOUT-7'), findsOneWidget);
  });

  testWidgets('OrbitLostModal displays Figma layout, score and action buttons correctly',
      (WidgetTester tester) async {
    bool retried = false;
    bool menuOpened = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OrbitLostModal(
              score: 2480,
              level: 8,
              highScore: 8640,
              runStarDust: 60,
              totalWalletStarDust: 1300,
              onRetry: () => retried = true,
              onMenu: () => menuOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEVEL 8 · RUN ENDED'), findsOneWidget);
    expect(find.text('ORBIT LOST'), findsOneWidget);
    expect(find.text('Every orbit is a new beginning.'), findsOneWidget);
    expect(find.text('2,480'), findsOneWidget);
    expect(find.text('High Score 8,640'), findsOneWidget);
    expect(find.text('+60 Stardust'), findsOneWidget);
    expect(find.text('Wallet 1,300'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);

    final retryBtn = find.text('RETRY');
    await tester.ensureVisible(retryBtn);
    await tester.tap(retryBtn);
    expect(retried, isTrue);

    final menuBtn = find.text('MENU');
    await tester.ensureVisible(menuBtn);
    await tester.tap(menuBtn);
    expect(menuOpened, isTrue);
  });

  testWidgets('LevelCompleteModal displays Figma breakdown, bonus and next sector footnote',
      (WidgetTester tester) async {
    bool nextLevelTapped = false;
    bool menuTapped = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LevelCompleteModal(
              score: 3960,
              level: 8,
              highScore: 8640,
              combo: 3,
              sectorStarDust: 180,
              totalWalletStarDust: 1420,
              onNextLevel: () => nextLevelTapped = true,
              onMenu: () => menuTapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEVEL 8 · ALL ORBITS CAPTURED'), findsOneWidget);
    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(find.text('The universe opens a little further.'), findsOneWidget);
    expect(find.text('3,960'), findsOneWidget);
    expect(find.text('Stage cleared'), findsOneWidget);
    expect(find.text('Flawless combo x3'), findsOneWidget);
    expect(find.text('Stardust earned'), findsOneWidget);
    expect(find.text('+180'), findsOneWidget);
    expect(find.text('Wallet 1,420 Stardust · High Score 8,640'), findsOneWidget);
    expect(find.text('NEXT LEVEL'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);

    final nextLevelBtn = find.text('NEXT LEVEL');
    await tester.ensureVisible(nextLevelBtn);
    await tester.tap(nextLevelBtn);
    expect(nextLevelTapped, isTrue);

    final menuBtn = find.text('MENU');
    await tester.ensureVisible(menuBtn);
    await tester.tap(menuBtn);
    expect(menuTapped, isTrue);
  });

  testWidgets('Settings modal opens from Main Menu and interacts with SOUND & FEEL and SYSTEM controls, dynamically updating language',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NeonOrbitApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the settings icon button on top-left of Main Menu
    final settingsButton = find.byKey(const Key('menu_settings_button'));
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Settings UI headers and labels in English initially
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('SOUND & FEEL'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('SYSTEM'), findsOneWidget);
    expect(find.text('Reduced motion'), findsOneWidget);
    expect(find.text('Graphics quality'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Color blind mode'), findsOneWidget);
    expect(find.text('GALAXY ORBIT · v1.0.0'), findsOneWidget);

    // Verify initial values
    expect(find.text('High'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Tap Graphics quality row to cycle
    await tester.tap(find.text('Graphics quality'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Medium'), findsOneWidget);

    // Tap Language row to cycle to Türkçe
    await tester.tap(find.text('Language'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Türkçe'), findsOneWidget);

    // Verify Settings UI headers and labels updated dynamically to Türkçe
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('SES VE HİSSİYAT'), findsOneWidget);
    expect(find.text('Müzik'), findsOneWidget);
    expect(find.text('Ses efektleri'), findsOneWidget);
    expect(find.text('Titreşimli geri bildirim'), findsOneWidget);
    expect(find.text('SİSTEM'), findsOneWidget);
    expect(find.text('Hareketi azalt'), findsOneWidget);
    expect(find.text('Grafik kalitesi'), findsOneWidget);
    expect(find.text('Orta'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Renk körlüğü modu'), findsOneWidget);

    // Tap close button (Icons.close_rounded)
    final closeIcon = find.byIcon(Icons.close_rounded);
    expect(closeIcon, findsOneWidget);
    await tester.tap(closeIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Modal is closed, Main Menu is now localized in Turkish!
    expect(find.text('OYNA'), findsOneWidget);
    expect(find.text('Hangar / Göksel Pazar'), findsOneWidget);

    // Reopen settings and switch back to English
    final settingsBtnAfter = find.byKey(const Key('menu_settings_button'));
    await tester.tap(settingsBtnAfter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Dil'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    final closeIconEn = find.byIcon(Icons.close_rounded);
    await tester.tap(closeIconEn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Back to English on Main Menu
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('Hangar / Celestial Market'), findsOneWidget);
  });

  testWidgets('In-Game HUD settings button opens settings modal and returns seamlessly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NeonOrbitApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap PLAY to start game
    final playBtn = find.text('PLAY');
    await tester.tap(playBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // In-Game settings button should be visible
    final inGameSettings = find.byKey(const Key('game_settings_button'));
    expect(inGameSettings, findsOneWidget);

    // Tap in-game settings
    await tester.tap(inGameSettings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Settings modal is displayed over game
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('SOUND & FEEL'), findsOneWidget);

    // Close settings
    final closeIcon = find.byIcon(Icons.close_rounded);
    await tester.tap(closeIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Returned to game seamlessly
    expect(find.byKey(const Key('game_settings_button')), findsOneWidget);
  });
}
