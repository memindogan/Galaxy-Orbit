import 'package:flutter/material.dart';

/// Enum representing the 4 distinct trail and launch shockwave styles.
enum CustomizationStyle {
  classic,
  sparkle,
  dualIon,
  cyberGlitch,
}

/// Data model for a cosmic customization bundle (Trail + Launch Shockwave).
class CosmicCustomization {
  final String id;
  final CustomizationStyle style;
  final String nameEn;
  final String nameTr;
  final String tagEn;
  final String tagTr;
  final String subtitleEn;
  final String subtitleTr;
  final String descriptionEn;
  final String descriptionTr;
  final int price;
  final Color primaryColor;
  final Color secondaryColor;

  const CosmicCustomization({
    required this.id,
    required this.style,
    required this.nameEn,
    required this.nameTr,
    required this.tagEn,
    required this.tagTr,
    required this.subtitleEn,
    required this.subtitleTr,
    required this.descriptionEn,
    required this.descriptionTr,
    required this.price,
    required this.primaryColor,
    required this.secondaryColor,
  });

  String name(bool isTurkish) => isTurkish ? nameTr : nameEn;
  String tag(bool isTurkish) => isTurkish ? tagTr : tagEn;
  String subtitle(bool isTurkish) => isTurkish ? subtitleTr : subtitleEn;
  String description(bool isTurkish) => isTurkish ? descriptionTr : descriptionEn;
}

/// Catalog of all available Cosmic Customizations in the Hangar.
class CustomizationCatalog {
  static const int standardPrice = 500;

  static const List<CosmicCustomization> items = [
    CosmicCustomization(
      id: 'classic',
      style: CustomizationStyle.classic,
      nameEn: 'Classic Neon',
      nameTr: 'Klasik Neon',
      tagEn: 'STARTER FX',
      tagTr: 'BAŞLANGIÇ EFEKTİ',
      subtitleEn: 'Plasma Ribbon · Gravity Ring',
      subtitleTr: 'Plazma Şeridi · Yerçekimi Halkası',
      descriptionEn: 'Clean luminous plasma trail with a classic gravitational launch ripple.',
      descriptionTr: 'Klasik yerçekimi fırlatma halkası ve pürüzsüz neon plazma kuyruk izi.',
      price: 0,
      primaryColor: Color(0xFF8CEFFF),
      secondaryColor: Color(0xFF38BDF8),
    ),
    CosmicCustomization(
      id: 'sparkle',
      style: CustomizationStyle.sparkle,
      nameEn: 'Stardust Sparkle',
      nameTr: 'Yıldız Tozu',
      tagEn: 'STELLAR FX',
      tagTr: 'YILDIZ EFEKTİ',
      subtitleEn: 'Crystal Trail · Starburst Wave',
      subtitleTr: 'Kristal İz · Yıldız Patlaması Dalgası',
      descriptionEn: 'Leaves shimmering 4-pointed star crystals and erupts in a prismatic starburst wave.',
      descriptionTr: 'Arkada parıldayan yıldız kristalleri bırakır ve prizmatik yıldız dalgasıyla fırlatır.',
      price: standardPrice,
      primaryColor: Color(0xFFFDE047),
      secondaryColor: Color(0xFFF472B6),
    ),
    CosmicCustomization(
      id: 'dual_ion',
      style: CustomizationStyle.dualIon,
      nameEn: 'Dual Ion',
      nameTr: 'İkiz İyon',
      tagEn: 'OVERDRIVE FX',
      tagTr: 'HIZ EFEKTİ',
      subtitleEn: 'Twin Racing Beams · Sonic Boom',
      subtitleTr: 'Çift Yarış Hattı · Sonik Patlama',
      descriptionEn: 'Twin parallel high-velocity ion streams paired with a double-ring sonic shockwave.',
      descriptionTr: 'Çift paralel yüksek hızlı iyon hattı ve ikiz halkalı sonik fırlatma dalgası.',
      price: standardPrice,
      primaryColor: Color(0xFF2DD4BF),
      secondaryColor: Color(0xFF818CF8),
    ),
    CosmicCustomization(
      id: 'cyber_glitch',
      style: CustomizationStyle.cyberGlitch,
      nameEn: 'Cyber Glitch',
      nameTr: 'Siber Glitch',
      tagEn: 'CYBERPUNK FX',
      tagTr: 'SİBER EFEKT',
      subtitleEn: 'Digital Matrix · Octagon Pulse',
      subtitleTr: 'Dijital Bloklar · Sekizgen Dalga',
      descriptionEn: 'Retro-futuristic digital neon data fragments and an octagonal cyber-grid launch wave.',
      descriptionTr: 'Retro-fütüristik dijital veri blokları ve sekizgen siber-grid fırlatma dalgası.',
      price: standardPrice,
      primaryColor: Color(0xFFE879F9),
      secondaryColor: Color(0xFF22D3EE),
    ),
  ];

  static CosmicCustomization getById(String? id) {
    if (id == null || id.isEmpty) return items.first;
    for (final item in items) {
      if (item.id.toLowerCase() == id.toLowerCase()) {
        return item;
      }
    }
    return items.first;
  }
}
