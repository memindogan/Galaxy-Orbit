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
  String journeyContinue(int best) =>
      isTurkish ? 'Yolculuğa devam et · En iyi mesafe $best' : 'Continue your journey · Best distance $best';
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

  // ─── Orbit Lost Modal (Game Over) ─────────────────────────────────────────
  String runEnded(int l) =>
      isTurkish ? 'SEVİYE $l · UÇUŞ SONLANDI' : 'LEVEL $l · RUN ENDED';
  String get orbitLost => isTurkish ? 'YÖRÜNGE KAYBEDİLDİ' : 'ORBIT LOST';
  String get orbitLostQuote =>
      isTurkish ? 'Her yörünge yeni bir başlangıçtır.' : 'Every orbit is a new beginning.';
  String get runScore => isTurkish ? 'KOŞU SKORU' : 'RUN SCORE';
  String highScoreLabel(String score) =>
      isTurkish ? 'En Yüksek Skor $score' : 'High Score $score';
  String get retry => isTurkish ? 'TEKRAR DENE' : 'RETRY';
  String get menu => isTurkish ? 'MENÜ' : 'MENU';
  String stardustPill(int amount) => '+$amount Stardust';
  String walletPill(String amount) =>
      isTurkish ? 'Cüzdan $amount' : 'Wallet $amount';

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
  String unlockedWorlds(int count, int total) =>
      isTurkish ? '$count / $total kilit açık' : '$count / $total unlocked';
  String get equipped => isTurkish ? 'Kuşanıldı' : 'Equipped';
  String get equip => isTurkish ? 'Kuşan' : 'Equip';
  String get equippedBadge => isTurkish ? 'KUŞANILDI' : 'EQUIPPED';
  String get equippedFleetButton => isTurkish ? 'KUŞANILAN FİLO' : 'EQUIPPED FLEET';
  String equipPlanetButton(String name) =>
      isTurkish ? 'KUŞAN · $name' : 'EQUIP · $name';
  String unlockPlanetButton(int price) =>
      isTurkish ? 'KİLİDİ AÇ · $price STARDUST' : 'UNLOCK · $price STARDUST';

  String get activeWorldNote =>
      isTurkish ? 'Yolculuklarınızdaki aktif dünya ve gemi' : 'Active world and vessel in your journeys';
  String get readyToDeployNote =>
      isTurkish ? 'Yörüngeye fırlatılmaya hazır' : 'Ready to deploy into orbit';
  String afterUnlockNote(int remaining) =>
      isTurkish ? 'Uydu dahildir · Kilit açıldıktan sonra $remaining Stardust' : 'Includes companion · $remaining Stardust after unlock';

  String equippedSnackbar(String world, String comp) =>
      isTurkish ? '$world ve $comp kuşanıldı!' : '$world and $comp equipped!';
  String unlockedSnackbar(String world, String comp) =>
      isTurkish ? '$world ve $comp kilidi açıldı ve kuşanıldı!' : 'Unlocked $world & $comp!';
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
