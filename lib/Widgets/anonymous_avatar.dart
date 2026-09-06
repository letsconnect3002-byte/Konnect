import 'package:flutter/material.dart';

/// A sleek, glassmorphic geometric avatar representing an anonymous user.
/// Deterministically chooses a harmonious color gradient and geometric symbol
/// based on a provided [seed] (such as authorId or anonName).
class AnonymousAvatar extends StatelessWidget {
  final String seed;
  final double radius;
  final Color? borderColor;

  const AnonymousAvatar({
    super.key,
    required this.seed,
    this.radius = 18.0,
    this.borderColor,
  });

  static const List<List<Color>> _palettes = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo to Purple
    [Color(0xFF0EA5E9), Color(0xFF3B82F6)], // Sky to Blue
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald to Teal
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber to Warm Gold
    [Color(0xFFEC4899), Color(0xFF8B5CF6)], // Pink to Violet
    [Color(0xFF14B8A6), Color(0xFF0284C7)], // Teal to Cyan
    [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Purple to Fuchsia
    [Color(0xFF64748B), Color(0xFF475569)], // Slate Steel
  ];

  static const List<IconData> _symbols = [
    Icons.fingerprint_rounded,
    Icons.hive_rounded,
    Icons.all_inclusive_rounded,
    Icons.blur_on_rounded,
    Icons.auto_awesome_rounded,
    Icons.lens_blur_rounded,
    Icons.grain_rounded,
    Icons.stream_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final int hash = seed.hashCode.abs();
    final List<Color> palette = _palettes[hash % _palettes.length];
    final IconData icon = _symbols[(hash ~/ _palettes.length) % _symbols.length];

    final double diameter = radius * 2;
    final double iconSize = radius * 1.1;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette[0].withValues(alpha: 0.85),
            palette[1].withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: palette[0].withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}
