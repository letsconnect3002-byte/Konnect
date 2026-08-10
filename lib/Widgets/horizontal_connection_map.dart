import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/profile_provider.dart';

class HorizontalConnectionMap extends StatefulWidget {
  final Map<String, dynamic>? selectedMutual;
  final String targetName;
  final String? targetAvatarUrl;
  final int degree;

  const HorizontalConnectionMap({
    super.key,
    required this.selectedMutual,
    required this.targetName,
    this.targetAvatarUrl,
    this.degree = 2,
  });

  @override
  State<HorizontalConnectionMap> createState() =>
      _HorizontalConnectionMapState();
}

class _HorizontalConnectionMapState extends State<HorizontalConnectionMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final myName =
        profileProvider.name.isNotEmpty ? profileProvider.name : 'You';
    final myAvatar = profileProvider.avatarUrl;

    final String mutualName;
    final String mutualAvatar;
    final String interName;
    final String interAvatar;

    if (widget.selectedMutual != null) {
      mutualName = widget.selectedMutual!['name']?.toString() ??
          widget.selectedMutual!['mutual_name']?.toString() ??
          'Mutual';
      mutualAvatar = widget.selectedMutual!['avatarUrl']?.toString() ??
          widget.selectedMutual!['mutual_avatar_url']?.toString() ??
          widget.selectedMutual!['avatar_url']?.toString() ??
          '';

      final rawInterName =
          widget.selectedMutual!['intermediary_name']?.toString() ??
              widget.selectedMutual!['second_degree_name']?.toString() ??
              widget.selectedMutual!['bridge_name']?.toString() ??
              '';
      final rawInterAvatar =
          widget.selectedMutual!['intermediary_avatar']?.toString() ??
              widget.selectedMutual!['second_degree_avatar']?.toString() ??
              widget.selectedMutual!['bridge_avatar']?.toString() ??
              '';

      if (rawInterName.isNotEmpty) {
        interName = rawInterName;
        interAvatar = rawInterAvatar;
      } else {
        interName = "2° Contact";
        interAvatar = '';
      }
    } else {
      mutualName = 'Mutual Friend';
      mutualAvatar = '';
      interName = "2° Contact";
      interAvatar = '';
    }

    final bool isMutualSelected = widget.selectedMutual != null;
    final bool is3rdDegree = widget.degree == 3;
    final double avatarSize = is3rdDegree ? 38.0 : 42.0;

    final Color lineActiveColor = context.accentSecondary;
    final Color lineInactiveColor = context.textMuted.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 14),
      padding: EdgeInsets.symmetric(
        horizontal: is3rdDegree ? 8 : 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.borderMuted.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node 1: You (Self - 0 hops)
          _buildNode(
            context,
            name: myName,
            roleLabel: "You",
            degreeBadge: null,
            avatarUrl: myAvatar,
            isPlaceholder: false,
            avatarSize: avatarSize,
          ),

          // Line 1: Existing Connection (You ↔ Mutual) - Solid, Clean
          Expanded(
            child: SizedBox(
              height: avatarSize,
              child: Center(
                child: CustomPaint(
                  size: const Size(double.infinity, 20),
                  painter: _ConnectorPainter(
                    progress: 0.0,
                    lineColor:
                        isMutualSelected ? lineActiveColor : lineInactiveColor,
                    isExisting: true,
                    isActive: isMutualSelected,
                  ),
                ),
              ),
            ),
          ),

          // Node 2: 1st Degree Mutual Connection
          _buildNode(
            context,
            name: mutualName,
            roleLabel: is3rdDegree ? "1° Friend" : "Mutual",
            degreeBadge: "1°",
            avatarUrl: mutualAvatar,
            isPlaceholder: !isMutualSelected,
            avatarSize: avatarSize,
          ),

          // Node 3 & Line 2 (Only present for 3rd Degree Connections - 4 profiles total)
          if (is3rdDegree) ...[
            Expanded(
              child: SizedBox(
                height: avatarSize,
                child: Center(
                  child: CustomPaint(
                    size: const Size(double.infinity, 20),
                    painter: _ConnectorPainter(
                      progress: 0.0,
                      lineColor: isMutualSelected
                          ? lineActiveColor
                          : lineInactiveColor,
                      isExisting: true,
                      isActive: isMutualSelected,
                    ),
                  ),
                ),
              ),
            ),
            _buildNode(
              context,
              name: interName,
              roleLabel: "2° Contact",
              degreeBadge: "2°",
              avatarUrl: interAvatar,
              isPlaceholder: !isMutualSelected,
              avatarSize: avatarSize,
            ),
          ],

          // Final Line: Potential Connection (Mutual/Contact → Target) - Dashed Wedged Arrows >>>
          Expanded(
            child: SizedBox(
              height: avatarSize,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, 20),
                      painter: _ConnectorPainter(
                        progress: _animController.value,
                        lineColor: isMutualSelected
                            ? lineActiveColor
                            : lineInactiveColor,
                        isExisting: false,
                        isActive: isMutualSelected,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Node Final: Target Person (2° or 3°)
          _buildNode(
            context,
            name: widget.targetName,
            roleLabel: "Target",
            degreeBadge: is3rdDegree ? "3°" : "2°",
            avatarUrl: widget.targetAvatarUrl ?? '',
            isPlaceholder: false,
            avatarSize: avatarSize,
          ),
        ],
      ),
    );
  }

  Widget _buildNode(
    BuildContext context, {
    required String name,
    required String roleLabel,
    String? degreeBadge,
    required String avatarUrl,
    bool isPlaceholder = false,
    double avatarSize = 42.0,
  }) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final textWidth = avatarSize > 40.0 ? 56.0 : 46.0;

    final borderColor = isPlaceholder
        ? context.textMuted.withValues(alpha: 0.25)
        : context.borderMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: avatarUrl.startsWith('http')
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: avatarSize * 0.55,
                            color: isPlaceholder
                                ? context.textMuted
                                : context.textSecondary,
                          ),
                        ),
                      )
                    : Center(
                        child: (isPlaceholder && avatarUrl.isEmpty) ||
                                name.contains('2°')
                            ? Icon(
                                Icons.person_rounded,
                                size: avatarSize * 0.55,
                                color: isPlaceholder
                                    ? context.textMuted
                                    : context.textSecondary,
                              )
                            : Text(
                                _getInitials(name),
                                style: TextStyle(
                                  color: isPlaceholder
                                      ? context.textMuted
                                      : context.textPrimary,
                                  fontSize: avatarSize > 40.0 ? 11.5 : 10.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
              ),
            ),
            if (degreeBadge != null && degreeBadge.isNotEmpty)
              Positioned(
                right: -3,
                bottom: -1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isPlaceholder
                        ? context.surfaceSecondary
                        : context.accentSecondary,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: context.surfacePrimary, width: 1),
                  ),
                  child: Text(
                    degreeBadge,
                    style: TextStyle(
                      color: isPlaceholder ? context.textMuted : Colors.white,
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: textWidth,
          child: Text(
            firstName,
            style: context.bodyText.copyWith(
              fontSize: avatarSize > 40.0 ? 10.5 : 9.5,
              fontWeight: FontWeight.w600,
              color: isPlaceholder ? context.textMuted : context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          roleLabel,
          style: context.captionText.copyWith(
            fontSize: avatarSize > 40.0 ? 9.0 : 8.0,
            color: isPlaceholder ? context.textMuted : context.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final double progress;
  final Color lineColor;
  final bool isExisting;
  final bool isActive;

  _ConnectorPainter({
    required this.progress,
    required this.lineColor,
    required this.isExisting,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    if (isExisting) {
      // Minimalistic solid connecting line (NO blur/glow)
      final linePaint = Paint()
        ..color = lineColor.withValues(alpha: isActive ? 0.7 : 0.25)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    } else {
      // Minimalistic dashed line with subtle directional arrowhead wedges (>>>)
      final baseColor = isActive ? lineColor : lineColor.withValues(alpha: 0.3);

      final linePaint = Paint()
        ..color = baseColor.withValues(alpha: isActive ? 0.5 : 0.2)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const dashWidth = 4.0;
      const dashSpace = 4.0;
      double startX = 0;
      while (startX < size.width) {
        final endX = (startX + dashWidth).clamp(0.0, size.width);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), linePaint);
        startX += dashWidth + dashSpace;
      }

      // Subtle directional wedges
      final wedgePaint = Paint()
        ..color = baseColor.withValues(alpha: isActive ? 0.85 : 0.35)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      const wedgeSpacing = 12.0;
      final offsetShift = isActive ? (progress * wedgeSpacing) : 0.0;

      for (double x = offsetShift; x < size.width - 3; x += wedgeSpacing) {
        if (x < 3) continue;
        final path = Path()
          ..moveTo(x - 2.5, y - 3.0)
          ..lineTo(x + 1.0, y)
          ..lineTo(x - 2.5, y + 3.0);
        canvas.drawPath(path, wedgePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.isExisting != isExisting ||
        oldDelegate.lineColor != lineColor;
  }
}
