import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/network_provider.dart';

class NetworkMap extends StatefulWidget {
  const NetworkMap({super.key});

  @override
  State<NetworkMap> createState() => _NetworkMapState();
}

class _NetworkMapState extends State<NetworkMap>
    with SingleTickerProviderStateMixin {
  final List<ConstellationParticle> _particles = [];
  final List<double> _dotOpacities = [];
  final List<Color> _dotColors = [
    const Color(0xFFFFDAB9), // Peach
    const Color(0xFFF08080), // Coral
    const Color(0xFFFFC0CB), // Blush Pink
    const Color(0xFFFFA07A), // Light Salmon
    const Color(0xFFFFE4B5), // Warm Orange
    const Color(0xFFE8E8E8), // Light Gray
  ];
  final List<Offset> _dotOffsets = [];
  final List<double> _dotSizes = [];
  final List<Color> _assignedDotColors = [];

  int?
      _selectedNodeIndex; // null = none, 0 = center, negative = primary connection, positive = secondary
  String? _selectedNodeName;

  @override
  void initState() {
    super.initState();
    final random = Random();

    // 1. Generate 100 atmospheric particles distributed between 30px and 220px radius
    for (int i = 0; i < 100; i++) {
      final double r = 30.0 + random.nextDouble() * 190.0;
      final double angle = random.nextDouble() * 2 * pi;
      final double size = 1.0 + random.nextDouble() * 1.0; // 1-2px
      final double opacity = 0.02 + random.nextDouble() * 0.06; // 2-8%
      final isBlue = random.nextDouble() < 0.15; // 15% blue particles
      final Color color = isBlue ? const Color(0xFFE0FFFF) : Colors.white;
      _particles.add(
        ConstellationParticle(
          offset: Offset(r * cos(angle), r * sin(angle)),
          size: size,
          opacity: opacity,
          color: color,
        ),
      );
    }

    // 2. Generate 10 floating accent dots placed in negative space (not overlapping slots)
    final List<double> dotRadii = [48, 76, 64, 88, 120, 152, 164, 108, 72, 172];
    final List<double> dotAngles = [
      -2.8,
      -0.8,
      0.9,
      2.1,
      -1.8,
      0.2,
      1.4,
      -2.5,
      3.0,
      -0.3
    ];
    final List<double> possibleSizes = [4.0, 6.0, 8.0, 10.0];
    for (int i = 0; i < 10; i++) {
      final double r = dotRadii[i];
      final double angle = dotAngles[i];
      _dotOffsets.add(Offset(r * cos(angle), r * sin(angle)));
      _dotSizes.add(possibleSizes[random.nextInt(possibleSizes.length)]);
      _assignedDotColors.add(_dotColors[random.nextInt(_dotColors.length)]);
      _dotOpacities.add(0.2 + random.nextDouble() * 0.65); // 20% to 85% opacity
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final networkProvider = Provider.of<NetworkProvider>(context);

    final String myAvatar = profileProvider.avatarUrl;
    final String myName = profileProvider.name;

    final primaryConnections = connectionProvider.connections.take(4).toList();
    final secondaryConnections = networkProvider.networkList.take(6).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double height = 300.0;
        final double cx = width / 2;
        const double cy =
            140.0; // Slightly above midpoint (46%) to center visual mass

        // Organic slot positions (relative to cx, cy)
        // Hand-arranged to form distinct clusters and isolates (non-geometric, non-symmetric)
        final List<Offset> slots = [
          const Offset(-85, -25), // Slot 0: Primary 1 (Left-top cluster)
          const Offset(-98, 25), // Slot 1: Primary 2 (Left-bottom cluster)
          const Offset(15, 105), // Slot 2: Primary 3 (Bottom isolated)
          const Offset(80, 15), // Slot 3: Primary 4 (Right cluster)
          const Offset(-45, 120), // Slot 4: Secondary 1 (Bottom-left isolated)
          const Offset(-135, -5), // Slot 5: Secondary 2 (Left cluster outer)
          const Offset(
              115, -20), // Slot 6: Secondary 3 (Right cluster outer top)
          const Offset(-40, -110), // Slot 7: Secondary 4 (Top-left isolated)
          const Offset(60, -90), // Slot 8: Secondary 5 (Top-right isolated)
          const Offset(
              110, 48), // Slot 9: Secondary 6 (Right cluster outer bottom)
        ];

        // Mixed sizes reduced a bit: Large (44px), Medium (36px), Small (28px) to create depth
        final List<double> slotSizes = [44, 36, 28, 44, 36, 28, 36, 28, 28, 28];

        // Map secondary connections to their primary connectors
        final List<int> secondaryToPrimaryMap = [];
        for (int j = 0; j < secondaryConnections.length; j++) {
          final sec = secondaryConnections[j];
          final String mutualNamesStr = sec["mutual_names"] ?? "";
          final List<String> mutualNames = mutualNamesStr
              .split(",")
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toList();

          int bestPrimaryIndex = 0;
          double minDistance = double.maxFinite;

          // Try to find a direct connection whose name matches a mutual connection name
          bool foundMatch = false;
          for (int i = 0; i < primaryConnections.length; i++) {
            final prim = primaryConnections[i];
            final String primName =
                (prim["name"] as String? ?? "").toLowerCase().trim();
            if (mutualNames.contains(primName)) {
              bestPrimaryIndex = i;
              foundMatch = true;
              break;
            }
          }

          // Fallback: connect to the angularly closest primary connection slot
          if (!foundMatch && primaryConnections.isNotEmpty) {
            final Offset secOffset = slots[4 + j];
            for (int i = 0; i < primaryConnections.length; i++) {
              final double dist = (secOffset - slots[i]).distance;
              if (dist < minDistance) {
                minDistance = dist;
                bestPrimaryIndex = i;
              }
            }
          }

          secondaryToPrimaryMap.add(bestPrimaryIndex);
        }

        return Container(
          height: height,
          width: width,
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.transparent, // Dissolves smoothly into white background
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Ambient Background (atmospheric particles and bezier connections, no glow)
              Positioned.fill(
                child: CustomPaint(
                  painter: AmbientConstellationPainter(
                    cx: cx,
                    cy: cy,
                    particles: _particles,
                    slots: slots,
                    primaryCount: primaryConnections.length,
                    secondaryCount: secondaryConnections.length,
                    secondaryToPrimaryMap: secondaryToPrimaryMap,
                    lineColor: context.accentSecondary,
                  ),
                ),
              ),

              // 2. Floating Accent Dots
              for (int i = 0; i < _dotOffsets.length; i++)
                Positioned(
                  left: cx + _dotOffsets[i].dx - (_dotSizes[i] / 2),
                  top: cy + _dotOffsets[i].dy - (_dotSizes[i] / 2),
                  child: Container(
                    width: _dotSizes[i],
                    height: _dotSizes[i],
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _assignedDotColors[i]
                          .withValues(alpha: _dotOpacities[i]),
                    ),
                  ),
                ),

              // 3. Secondary Connections (Outer layer - Question mark nodes)
              for (int j = 0; j < secondaryConnections.length; j++) ...[
                if (4 + j < slots.length)
                  () {
                    final int slotIndex = 4 + j;
                    final Offset pos = Offset(
                        cx + slots[slotIndex].dx, cy + slots[slotIndex].dy);
                    final double size = slotSizes[slotIndex];
                    final sec = secondaryConnections[j];

                    // Visual depth based on size
                    final double borderOpacity =
                        size >= 44 ? 1.0 : (size >= 36 ? 0.92 : 0.85);
                    final double shadowOpacity =
                        size >= 44 ? 0.09 : (size >= 36 ? 0.07 : 0.05);
                    final double shadowBlur =
                        size >= 44 ? 12 : (size >= 36 ? 9 : 6);
                    final Offset shadowOffset = size >= 44
                        ? const Offset(0, 3.5)
                        : (size >= 36
                            ? const Offset(0, 2.5)
                            : const Offset(0, 1.5));

                    return Positioned(
                      left: pos.dx - (size / 2),
                      top: pos.dy - (size / 2),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedNodeIndex = j + 1;
                            _selectedNodeName =
                                sec["name"] ?? "Secondary Connection";
                          });
                        },
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedNodeIndex == j + 1
                                  ? context.accentSecondary
                                  : Colors.white
                                      .withValues(alpha: borderOpacity),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: shadowOpacity),
                                offset: shadowOffset,
                                blurRadius: shadowBlur,
                              ),
                              if (_selectedNodeIndex == j + 1)
                                BoxShadow(
                                  color: context.accentSecondary
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: ClipOval(
                            child: Container(
                              color: context.surfaceSecondary,
                              alignment: Alignment.center,
                              child: Text(
                                "?",
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: size * 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],

              // 4. Primary Connections (Inner layer - Real connection avatars)
              for (int i = 0; i < primaryConnections.length; i++) ...[
                if (i < slots.length)
                  () {
                    final Offset pos =
                        Offset(cx + slots[i].dx, cy + slots[i].dy);
                    final double size = slotSizes[i];
                    final prim = primaryConnections[i];

                    // Visual depth based on size
                    final double borderOpacity =
                        size >= 44 ? 1.0 : (size >= 36 ? 0.92 : 0.85);
                    final double shadowOpacity =
                        size >= 44 ? 0.09 : (size >= 36 ? 0.07 : 0.05);
                    final double shadowBlur =
                        size >= 44 ? 12 : (size >= 36 ? 9 : 6);
                    final Offset shadowOffset = size >= 44
                        ? const Offset(0, 3.5)
                        : (size >= 36
                            ? const Offset(0, 2.5)
                            : const Offset(0, 1.5));

                    return Positioned(
                      left: pos.dx - (size / 2),
                      top: pos.dy - (size / 2),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedNodeIndex = -(i + 1);
                            _selectedNodeName =
                                prim["name"] ?? "Direct Connection";
                          });
                        },
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedNodeIndex == -(i + 1)
                                  ? context.accentSecondary
                                  : Colors.white
                                      .withValues(alpha: borderOpacity),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: shadowOpacity),
                                offset: shadowOffset,
                                blurRadius: shadowBlur,
                              ),
                              if (_selectedNodeIndex == -(i + 1))
                                BoxShadow(
                                  color: context.accentSecondary
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: ClipOval(
                            child: () {
                              final avatarUrl = prim["avatarUrl"]?.toString() ??
                                  prim["avatar_url"]?.toString() ??
                                  "";
                              final name = prim["name"]?.toString() ?? "?";
                              if (avatarUrl.isNotEmpty) {
                                return Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    color: context.surfaceSecondary,
                                    alignment: Alignment.center,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name.substring(0, 1).toUpperCase()
                                          : "?",
                                      style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: size * 0.35),
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                color: context.surfaceSecondary,
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: size * 0.35),
                                ),
                              );
                            }(),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],

              // 5. Central User Avatar (Diameter 72px / Radius 36px)
              Positioned(
                left: cx - 36,
                top: cy - 36,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedNodeIndex = 0;
                      _selectedNodeName = "$myName (You)";
                    });
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4.0, // Thin white outline
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: myAvatar.isNotEmpty
                          ? Image.network(myAvatar, fit: BoxFit.cover)
                          : Container(
                              color: context.surfaceSecondary,
                              alignment: Alignment.center,
                              child: Text(
                                myName.isNotEmpty
                                    ? myName.substring(0, 1).toUpperCase()
                                    : "?",
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // 6. Selected Connection Name Tooltip Badge
              if (_selectedNodeName != null)
                Positioned(
                  left: 16,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedNodeIndex == 0
                              ? Icons.person_rounded
                              : (_selectedNodeIndex! < 0
                                  ? Icons.link_rounded
                                  : Icons.help_outline_rounded),
                          size: 14,
                          color: context.accentSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedNodeName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ConstellationParticle {
  final Offset offset;
  final double size;
  final double opacity;
  final Color color;

  ConstellationParticle({
    required this.offset,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

class AmbientConstellationPainter extends CustomPainter {
  final double cx;
  final double cy;
  final List<ConstellationParticle> particles;
  final List<Offset> slots;
  final int primaryCount;
  final int secondaryCount;
  final List<int> secondaryToPrimaryMap;
  final Color lineColor;

  AmbientConstellationPainter({
    required this.cx,
    required this.cy,
    required this.particles,
    required this.slots,
    required this.primaryCount,
    required this.secondaryCount,
    required this.secondaryToPrimaryMap,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    final Paint linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final Offset p0 = Offset(cx, cy);

    // 1. Draw curved connecting lines from center to primary connections
    for (int i = 0; i < primaryCount; i++) {
      if (i < slots.length) {
        final Offset offset = slots[i];
        final Offset p2 = Offset(cx + offset.dx, cy + offset.dy);

        // Calculate unique curve control point
        final Offset mid = Offset((p0.dx + p2.dx) / 2, (p0.dy + p2.dy) / 2);
        final double dx = p2.dx - p0.dx;
        final double dy = p2.dy - p0.dy;
        final double sign = (i % 2 == 0) ? 1.0 : -1.0;
        final Offset perp = Offset(-dy * sign, dx * sign);
        final double len = perp.distance;
        final double factor = 0.04 + (i * 0.05); // Unique curve shape
        final Offset controlPoint =
            mid + (perp / (len == 0 ? 1 : len)) * (len * factor);

        path.reset();
        path.moveTo(p0.dx, p0.dy);
        path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, p2.dx, p2.dy);
        canvas.drawPath(path, linePaint);
      }
    }

    // 2. Draw curved connecting lines from primary to secondary connections
    for (int j = 0; j < secondaryCount; j++) {
      final int slotIndex = 4 + j;
      if (slotIndex < slots.length && j < secondaryToPrimaryMap.length) {
        final int primaryIndex = secondaryToPrimaryMap[j];
        if (primaryIndex < primaryCount && primaryIndex < slots.length) {
          final Offset pOffset = slots[primaryIndex];
          final Offset sOffset = slots[slotIndex];

          final Offset start = Offset(cx + pOffset.dx, cy + pOffset.dy);
          final Offset end = Offset(cx + sOffset.dx, cy + sOffset.dy);

          // Calculate unique curve control point
          final Offset mid =
              Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
          final double dx = end.dx - start.dx;
          final double dy = end.dy - start.dy;
          final double sign = (j % 2 == 0) ? 1.0 : -1.0;
          final Offset perp = Offset(-dy * sign, dx * sign);
          final double len = perp.distance;
          final double factor = 0.06 + (j * 0.03); // Unique curve shape
          final Offset controlPoint =
              mid + (perp / (len == 0 ? 1 : len)) * (len * factor);

          path.reset();
          path.moveTo(start.dx, start.dy);
          path.quadraticBezierTo(
              controlPoint.dx, controlPoint.dy, end.dx, end.dy);
          canvas.drawPath(path, linePaint);
        }
      }
    }

    // 3. Draw atmospheric particles
    for (final p in particles) {
      final Paint particlePaint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(cx + p.offset.dx, cy + p.offset.dy), p.size, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
