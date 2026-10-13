import 'package:flutter/material.dart';

/// Represents a celestial world and its companion vessel in Celestial Market.
class FleetPlanet {
  final String id;
  final String name;
  final String category; // e.g. "Terrestrial", "Crimson desert", "Gas giant"
  final String bundleTag; // e.g. "STARTER BUNDLE", "SCOUT BUNDLE", "EXOTIC BUNDLE"
  final String companionName; // e.g. "Luna", "Scout-7", "Ion Harvester"
  final String companionType; // e.g. "natural moon", "reconnaissance probe", "mining vessel"
  final int price; // in Stardust
  final String assetPath;
  final Color primaryColor;
  final Color glowColor;
  final Color companionColor;
  final double orbitRadius;

  const FleetPlanet({
    required this.id,
    required this.name,
    required this.category,
    required this.bundleTag,
    required this.companionName,
    required this.companionType,
    required this.price,
    required this.assetPath,
    required this.primaryColor,
    required this.glowColor,
    this.companionColor = const Color(0xFF8CEFFF),
    this.orbitRadius = 140.0,
  });

  String get subtitle => '$companionName · $companionType';
  String get heroSubtitle => '$category + $companionName $companionType';
}

/// The full catalog of 12 celestial worlds in Galaxy Orbit.
class FleetCatalog {
  static const List<FleetPlanet> worlds = [
    FleetPlanet(
      id: 'terra',
      name: 'Terra',
      category: 'Terrestrial',
      bundleTag: 'STARTER BUNDLE',
      companionName: 'Luna',
      companionType: 'natural moon',
      price: 0,
      assetPath: 'assets/images/planet_terra.jpg',
      primaryColor: Color(0xFF8CEFFF),
      glowColor: Color(0xFF4DA3FF),
      companionColor: Color(0xFFDBEAF5),
      orbitRadius: 139.65,
    ),
    FleetPlanet(
      id: 'ember',
      name: 'Ember',
      category: 'Crimson desert',
      bundleTag: 'RECON BUNDLE',
      companionName: 'Scout-7',
      companionType: 'reconnaissance probe',
      price: 450,
      assetPath: 'assets/images/planet_ember.jpg',
      primaryColor: Color(0xFFFF8A50),
      glowColor: Color(0xFFFF5722),
      companionColor: Color(0xFF8CEFFF),
      orbitRadius: 136.0,
    ),
    FleetPlanet(
      id: 'aether',
      name: 'Aether',
      category: 'Gas giant',
      bundleTag: 'EXOTIC BUNDLE',
      companionName: 'Ion Harvester',
      companionType: 'mining vessel',
      price: 900,
      assetPath: 'assets/images/planet_aether.jpg',
      primaryColor: Color(0xFFC084FC),
      glowColor: Color(0xFFA855F7),
      companionColor: Color(0xFF8CEFFF),
      orbitRadius: 144.0,
    ),
    FleetPlanet(
      id: 'chronos',
      name: 'Chronos',
      category: 'Time anomaly',
      bundleTag: 'ANOMALY BUNDLE',
      companionName: 'Vanguard-I',
      companionType: 'temporal observatory',
      price: 1400,
      assetPath: 'assets/images/planet_aether.jpg',
      primaryColor: Color(0xFF38BDF8),
      glowColor: Color(0xFF0284C7),
      companionColor: Color(0xFFBAE6FD),
      orbitRadius: 138.0,
    ),
    FleetPlanet(
      id: 'nova',
      name: 'Nova',
      category: 'Plasma sphere',
      bundleTag: 'SOLAR BUNDLE',
      companionName: 'Solaris',
      companionType: 'coronal skimmer',
      price: 1850,
      assetPath: 'assets/images/planet_ember.jpg',
      primaryColor: Color(0xFFFBBF24),
      glowColor: Color(0xFFD97706),
      companionColor: Color(0xFFFEF08A),
      orbitRadius: 142.0,
    ),
    FleetPlanet(
      id: 'titan',
      name: 'Titan',
      category: 'Cryo moon',
      bundleTag: 'GLACIAL BUNDLE',
      companionName: 'Hyperion',
      companionType: 'methane drifter',
      price: 2400,
      assetPath: 'assets/images/planet_terra.jpg',
      primaryColor: Color(0xFF2DD4BF),
      glowColor: Color(0xFF0D9488),
      companionColor: Color(0xFF99F6E4),
      orbitRadius: 135.0,
    ),
    FleetPlanet(
      id: 'gliese',
      name: 'Gliese',
      category: 'Oceanic world',
      bundleTag: 'ABYSS BUNDLE',
      companionName: 'Deep Probe',
      companionType: 'oceanic surveyor',
      price: 3000,
      assetPath: 'assets/images/planet_terra.jpg',
      primaryColor: Color(0xFF60A5FA),
      glowColor: Color(0xFF2563EB),
      companionColor: Color(0xFF93C5FD),
      orbitRadius: 140.0,
    ),
    FleetPlanet(
      id: 'nebula9',
      name: 'Nebula-9',
      category: 'Dark matter',
      bundleTag: 'COSMIC BUNDLE',
      companionName: 'Void Ray',
      companionType: 'matter harvester',
      price: 3800,
      assetPath: 'assets/images/planet_aether.jpg',
      primaryColor: Color(0xFFF472B6),
      glowColor: Color(0xFFDB2777),
      companionColor: Color(0xFFFBCFE8),
      orbitRadius: 145.0,
    ),
    FleetPlanet(
      id: 'solaris',
      name: 'Solaris',
      category: 'Fusion core',
      bundleTag: 'STELLAR BUNDLE',
      companionName: 'Helios',
      companionType: 'fusion collector',
      price: 4600,
      assetPath: 'assets/images/planet_ember.jpg',
      primaryColor: Color(0xFFFB923C),
      glowColor: Color(0xFFEA580C),
      companionColor: Color(0xFFFED7AA),
      orbitRadius: 137.0,
    ),
    FleetPlanet(
      id: 'eclipse',
      name: 'Eclipse',
      category: 'Shadow realm',
      bundleTag: 'SHADOW BUNDLE',
      companionName: 'Umbra',
      companionType: 'shadow drone',
      price: 5500,
      assetPath: 'assets/images/planet_aether.jpg',
      primaryColor: Color(0xFFA78BFA),
      glowColor: Color(0xFF7C3AED),
      companionColor: Color(0xFFDDD6FE),
      orbitRadius: 141.0,
    ),
    FleetPlanet(
      id: 'orion',
      name: 'Orion',
      category: 'Quantum belt',
      bundleTag: 'QUANTUM BUNDLE',
      companionName: 'Rigel-X',
      companionType: 'quantum relay',
      price: 6800,
      assetPath: 'assets/images/planet_terra.jpg',
      primaryColor: Color(0xFF34D399),
      glowColor: Color(0xFF059669),
      companionColor: Color(0xFFA7F3D0),
      orbitRadius: 139.0,
    ),
    FleetPlanet(
      id: 'void',
      name: 'Void',
      category: 'Singularity',
      bundleTag: 'MYTHIC BUNDLE',
      companionName: 'Infinity',
      companionType: 'singularity probe',
      price: 8500,
      assetPath: 'assets/images/planet_aether.jpg',
      primaryColor: Color(0xFFE879F9),
      glowColor: Color(0xFFC026D3),
      companionColor: Color(0xFFF5D0FE),
      orbitRadius: 146.0,
    ),
  ];

  static FleetPlanet getById(String? id) {
    if (id == null || id.isEmpty) {
      return worlds.first;
    }
    for (final world in worlds) {
      if (world.id.toLowerCase() == id.toLowerCase()) {
        return world;
      }
    }
    return worlds.first;
  }
}
