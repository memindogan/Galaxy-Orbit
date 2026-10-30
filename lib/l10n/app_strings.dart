/// Multi-language localization system for Galaxy Orbit.
/// Supports English and Türkçe dynamically.
library;

import '../providers/settings_provider.dart';

class AppStrings {
  final String language;
  final bool isTurkish;

  AppStrings(this.language) : isTurkish = (language == 'Türkçe');

  // ─── Main Menu ────────────────────────────────────────────────────────────
  String get galaxy => 'GALAXY';
  String get orbit => 'ORBIT';
  String get menuTagline =>
      isTurkish ? 'TEK DOKUNUŞ. SONSUZ OLASILIK' : 'ONE TAP. INFINITE POSSIBILITY';
  String get play => isTurkish ? 'OYNA' : 'PLAY';
  String get companion => isTurkish ? 'UYDUSU' : 'COMPANION';
  String get endlessMode => isTurkish ? 'SONSUZ' : 'ENDLESS';
  String get timeAttackMode => isTurkish ? 'ZAMANA KARŞI' : 'TIME ATTACK';
  String journeyContinue(int best) =>
      isTurkish ? 'Yolculuğa devam et · En iyi mesafe $best' : 'Continue your journey · Best distance $best';
  String timeAttackContinue(String bestScore) =>
      isTurkish ? 'Zamana Karşı · En iyi skor $bestScore' : 'Time Attack · Best score $bestScore';
  String get timeAttackBegin =>
      isTurkish ? '30sn Zamana Karşı · OYNA\'ya dokun' : '30s Time Attack · Tap PLAY';
  String get journeyBegin =>
      isTurkish ? 'Yolculuğa başla · OYNA\'ya dokun' : 'Begin your journey · Tap PLAY';
  String get hangarTitle =>
      isTurkish ? 'Hangar / Göksel Pazar' : 'Hangar / Celestial Market';
  String get settingsSemantic => isTurkish ? 'Ayarlar' : 'Settings';

  // ─── In-Game HUD & Canvas ─────────────────────────────────────────────────
  String level(int l) => isTurkish ? 'SEVİYE $l' : 'LEVEL $l';
  String captures(int count, int total) =>
      isTurkish ? '$count / $total yörünge' : '$count / $total captures';
  String score(String formattedScore) =>
      isTurkish ? 'SKOR $formattedScore' : 'SCORE $formattedScore';
  String combo(int c) => isTurkish ? 'KOMBO x$c' : 'COMBO x$c';
  String get tapToLaunch =>
      isTurkish ? 'FIRLATMAK İÇİN DOKUNUN' : 'TAP ANYWHERE TO LAUNCH';
  String nextPlanet(String name) =>
      isTurkish ? 'HEDEF: $name' : 'NEXT: $name';
  String get cwOrbit => isTurkish ? 'SAAT YÖNÜ' : 'CW ORBIT';
  String get ccwOrbit => isTurkish ? 'TERS SAAT YÖNÜ' : 'CCW ORBIT';
  String timeRemaining(String sec) => isTurkish ? '${sec}sn' : '${sec}s';

  // ─── Power-Ups & Hazard Feedback ──────────────────────────────────────────
  String get powerUpShield =>
      isTurkish ? 'MANYETİK KALKAN AKTİF' : 'AEGIS SHIELD ACTIVE';
  String get powerUpShieldSaved =>
      isTurkish ? 'KALKAN YÖRÜNGEYİ KURTARDI!' : 'SHIELD SAVED YOUR ORBIT!';
  String get powerUpShieldBrokeHazard =>
      isTurkish ? 'KALKAN ENGELİ PARÇALADI!' : 'SHIELD SHATTERED HAZARD!';
  String get powerUpGravityWell =>
      isTurkish ? 'SÜPER ÇEKİM ALANI (3 YÖRÜNGE)' : 'GRAVITY WELL (3 ORBITS)';
  String get powerUpChronoWarp =>
      isTurkish ? 'ZAMAN DURGUNLUĞU AKTİF' : 'CHRONO WARP ACTIVE';
  String get powerUpOverdrive =>
      isTurkish ? 'HİPER KOMBO DALGASI (2X)' : 'OVERDRIVE SURGE (2X)';
  String get powerUpQuantumLeap =>
      isTurkish ? 'KUANTUM SIÇRAMASI!' : 'QUANTUM LEAP!';

  // ─── Orbit Lost Modal (Game Over) ─────────────────────────────────────────
  String runEnded(int l) =>
      isTurkish ? 'SEVİYE $l · UÇUŞ SONLANDI' : 'LEVEL $l · RUN ENDED';
  String timeAttackEnded(int l) =>
      isTurkish ? 'ZAMANA KARŞI · SEVİYE $l' : 'TIME ATTACK · LEVEL $l';
  String get orbitLost => isTurkish ? 'YÖRÜNGE KAYBEDİLDİ' : 'ORBIT LOST';
  String get timeUpTitle => isTurkish ? 'SÜRE DOLDU' : 'TIME\'S UP';
  String get orbitLostQuote =>
      isTurkish ? 'Her yörünge yeni bir başlangıçtır.' : 'Every orbit is a new beginning.';
  String get timeUpQuote =>
      isTurkish ? 'Derin uzayda zaman bile hızına yetişemedi.' : 'Even in deep space, time waits for no one.';
  String get runScore => isTurkish ? 'KOŞU SKORU' : 'RUN SCORE';
  String highScoreLabel(String score) =>
      isTurkish ? 'En Yüksek Skor $score' : 'High Score $score';
  String get retry => isTurkish ? 'TEKRAR DENE' : 'RETRY';
  String get menu => isTurkish ? 'MENÜ' : 'MENU';
  String reviveLabel(int remaining, int max) =>
      isTurkish ? 'YÖRÜNGEYE DÖN ($remaining/$max)' : 'REVIVE ORBIT ($remaining/$max)';
  String get reviveExhausted =>
      isTurkish ? 'AF HAKKI DOLDU (0/3)' : 'NO REVIVES LEFT (0/3)';
  String get newHighBadge => isTurkish ? 'YENİ REKOR!' : 'NEW HIGH!';
  String orbitsPill(int count) => isTurkish ? '$count Yörünge' : '$count Orbits';
  String comboPill(int count) => isTurkish ? 'x$count Kombo' : 'x$count Combo';
  String signalLostCode(int l) =>
      'SIGNAL LOST / ${l.toString().padLeft(2, '0')}';
  String stardustPill(int amount) => '+$amount Stardust';
  String walletPill(String amount) =>
      isTurkish ? 'Cüzdan $amount' : 'Wallet $amount';
  String totalWalletFooter(String amount) =>
      isTurkish ? 'Toplam Cüzdan: $amount Stardust' : 'Total Wallet: $amount Stardust';

  // ─── Level / Sector Complete Modal ────────────────────────────────────────
  String allCaptured(int l) =>
      isTurkish ? 'SEVİYE $l · TÜM YÖRÜNGELER TAMAMLANDI' : 'LEVEL $l · ALL ORBITS CAPTURED';
  String get levelComplete =>
      isTurkish ? 'SEVİYE TAMAMLANDI' : 'LEVEL COMPLETE';
  String levelCompleteBanner(int l) =>
      isTurkish ? 'SEVİYE $l TAMAMLANDI' : 'LEVEL $l COMPLETED';
  String get levelCompleteQuote =>
      isTurkish ? 'Evren biraz daha aralanıyor.' : 'The universe opens a little further.';
  String get stageCleared => isTurkish ? 'Aşama tamamlandı' : 'Stage cleared';
  String flawlessCombo(int c) =>
      isTurkish ? 'Kusursuz kombo x$c' : 'Flawless combo x$c';
  String get stardustEarned => isTurkish ? 'Kazanılan Stardust' : 'Stardust earned';
  String get nextLevel => isTurkish ? 'SONRAKİ SEVİYE' : 'NEXT LEVEL';
  String walletHighScoreSummary(String wallet, String high) =>
      isTurkish ? 'Cüzdan $wallet Stardust · En Yüksek $high' : 'Wallet $wallet Stardust · High Score $high';
  String upNext(int nextLvl, String subtitle) =>
      isTurkish ? 'Sırada · Seviye $nextLvl · $subtitle' : 'Up next · Level $nextLvl · $subtitle';

  String sectorSubtitle(int lvl) {
    if (!isTurkish) {
      const titles = [
        'Orbital Acceleration',
        'Gravitational Resonance',
        'Plasma Belt Traversal',
        'Binary System Equilibrium',
        'Solar Flare Hazard',
        'Chronos Singularity',
        'Deep Void Navigation',
        'Cosmic Nebula Drift',
        'Hyperion Cryo Fields',
        'Titan Atmospheric Plunge',
        'Aether Magnetosphere',
        'Interstellar Abyss',
      ];
      return titles[(lvl - 1) % titles.length];
    }
    const trTitles = [
      'Yörünge İvmelenmesi',
      'Yerçekimsel Rezonans',
      'Plazma Kuşağı Geçişi',
      'İkili Sistem Dengesi',
      'Güneş Patlaması Tehlikesi',
      'Kronos Tekilliği',
      'Derin Boşluk Seyrüseferi',
      'Kozmik Bulutsu Sürüklenişi',
      'Hiperion Kriyojenik Alanları',
      'Titan Atmosferik Dalışı',
      'Esir Manyetosferi',
      'Yıldızlararası Uçurum',
    ];
    return trTitles[(lvl - 1) % trTitles.length];
  }

  // ─── Celestial Market / Hangar ────────────────────────────────────────────
  String get celestialMarket => isTurkish ? 'GÖKSEL PAZAR' : 'CELESTIAL MARKET';
  String get yourCosmicFleet => isTurkish ? 'Kozmik filonuz' : 'Your cosmic fleet';
  String get worldsAndCompanions => isTurkish ? 'Dünyalar & uydular' : 'Worlds & companions';
  String get customizationsTab => isTurkish ? 'Özelleştirmeler' : 'Customizations';
  String unlockedWorlds(int count, int total) =>
      isTurkish ? '$count / $total kilit açık' : '$count / $total unlocked';
  String get equipped => isTurkish ? 'Kuşanıldı' : 'Equipped';
  String get equip => isTurkish ? 'Kuşan' : 'Equip';
  String get equippedBadge => isTurkish ? 'KUŞANILDI' : 'EQUIPPED';
  String get equippedFleetButton => isTurkish ? 'KUŞANILAN FİLO' : 'EQUIPPED FLEET';
  String get equippedCustomizationButton =>
      isTurkish ? 'KUŞANILAN ÖZELLEŞTİRME' : 'EQUIPPED FX';
  String equipPlanetButton(String name) =>
      isTurkish ? 'KUŞAN · $name' : 'EQUIP · $name';
  String unlockPlanetButton(int price) =>
      isTurkish ? 'KİLİDİ AÇ · $price STARDUST' : 'UNLOCK · $price STARDUST';

  String get activeWorldNote =>
      isTurkish ? 'Yolculuklarınızdaki aktif dünya ve gemi' : 'Active world and vessel in your journeys';
  String get activeCustomizationNote =>
      isTurkish ? 'Uçuşlarınızda aktif kuyruk izi ve fırlatma dalgası' : 'Active trail and launch wave in your flights';
  String get readyToDeployNote =>
      isTurkish ? 'Yörüngeye fırlatılmaya hazır' : 'Ready to deploy into orbit';
  String get readyCustomizationNote =>
      isTurkish ? 'Geminizde kullanılmaya hazır' : 'Ready to equip on your vessel';
  String afterUnlockNote(int remaining) =>
      isTurkish ? 'Uydu dahildir · Kilit açıldıktan sonra $remaining Stardust' : 'Includes companion · $remaining Stardust after unlock';
  String afterUnlockCustomizationNote(int remaining) =>
      isTurkish ? 'Kuyruk izi + fırlatma dalgası · Kilit sonrası $remaining Stardust' : 'Trail + launch wave · $remaining Stardust after unlock';

  String equippedSnackbar(String world, String comp) =>
      isTurkish ? '$world ve $comp kuşanıldı!' : '$world and $comp equipped!';
  String unlockedSnackbar(String world, String comp) =>
      isTurkish ? '$world ve $comp kilidi açıldı ve kuşanıldı!' : 'Unlocked $world & $comp!';
  String equippedCustomizationSnackbar(String name) =>
      isTurkish ? '$name özelleştirmesi kuşanıldı!' : '$name customization equipped!';
  String unlockedCustomizationSnackbar(String name) =>
      isTurkish ? '$name kilidi açıldı ve kuşanıldı!' : 'Unlocked & equipped $name!';
  String needMoreDustSnackbar(String world, int needed) =>
      isTurkish ? '$world kilidini açmak için $needed Stardust daha gerekli!' : 'Need $needed more Stardust to unlock $world!';

  // ─── Settings Modal ───────────────────────────────────────────────────────
  String get settings => isTurkish ? 'Ayarlar' : 'Settings';
  String get soundAndFeel => isTurkish ? 'SES VE HİSSİYAT' : 'SOUND & FEEL';
  String get music => isTurkish ? 'Müzik' : 'Music';
  String get soundEffects => isTurkish ? 'Ses efektleri' : 'Sound effects';
  String get hapticFeedback => isTurkish ? 'Titreşimli geri bildirim' : 'Haptic feedback';
  String get system => isTurkish ? 'SİSTEM' : 'SYSTEM';
  String get reducedMotion => isTurkish ? 'Hareketi azalt' : 'Reduced motion';
  String get graphicsQuality => isTurkish ? 'Grafik kalitesi' : 'Graphics quality';
  String graphicsQualityLabel(GraphicsQuality q) {
    if (!isTurkish) return q.label;
    return switch (q) {
      GraphicsQuality.high => 'Yüksek',
      GraphicsQuality.medium => 'Orta',
      GraphicsQuality.low => 'Düşük',
    };
  }
  String get languageTitle => isTurkish ? 'Dil' : 'Language';
  String get colorBlindMode => isTurkish ? 'Renk körlüğü modu' : 'Color blind mode';
  String get versionFooter => 'GALAXY ORBIT · v1.0.0';
}
