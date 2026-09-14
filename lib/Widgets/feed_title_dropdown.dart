import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/custom_network.dart';
import 'package:connect/Providers/custom_network_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Widgets/create_custom_network_sheet.dart';
import 'package:connect/Widgets/discord_network_rail_drawer.dart';
import 'package:connect/Widgets/network_members_sheet.dart';

/// WhatsApp Communities-style Tappable Title Dropdown with Peek Animation.
///
/// Features:
/// - Tappable app bar title trigger with squircle icon, feed title, animated chevron (▼),
///   and unseen count badge.
/// - Fluid spring-animated glassmorphic dropdown menu anchored beneath the title.
/// - Unseen count badges for all built-in scopes and custom circles.
/// - First-launch subtle bounce & soft glow peek animation (persisted in SharedPreferences).
class FeedTitleDropdown extends StatefulWidget {
  final FeedFilter currentFilter;
  final CustomNetwork? activeCustomNetwork;
  final ValueChanged<FeedFilter>? onSelectFilter;
  final ValueChanged<CustomNetwork>? onSelectCustomNetwork;

  const FeedTitleDropdown({
    super.key,
    required this.currentFilter,
    this.activeCustomNetwork,
    this.onSelectFilter,
    this.onSelectCustomNetwork,
  });

  @override
  State<FeedTitleDropdown> createState() => _FeedTitleDropdownState();
}

class _FeedTitleDropdownState extends State<FeedTitleDropdown>
    with TickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  // Menu entrance animations controller
  late AnimationController _menuAnimController;
  late Animation<double> _menuFade;
  late Animation<double> _menuScale;
  late Animation<Offset> _menuSlide;

  // First-launch peek animation controller
  late AnimationController _peekController;
  late Animation<double> _peekScale;
  late Animation<double> _peekGlow;
  bool _isPlayingPeek = false;

  static const String _peekPrefKey = 'has_seen_feed_title_peek_v2';

  @override
  void initState() {
    super.initState();

    // Menu entrance animations (Apple spring-like feel)
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _menuFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _menuAnimController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
    );

    _menuScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _menuAnimController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _menuSlide = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _menuAnimController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // First-launch Peek Animation
    _peekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Subtle scale bounce: 1.0 -> 1.045 -> 0.985 -> 1.0
    _peekScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.045)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.045, end: 0.985)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.985, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
    ]).animate(_peekController);

    // Soft luminous glow pulse: 0.0 -> 1.0 -> 0.0
    _peekGlow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 60,
      ),
    ]).animate(_peekController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPlayFirstLaunchPeek();
    });
  }

  Future<void> _checkAndPlayFirstLaunchPeek() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_peekPrefKey) ?? false;
      if (!hasSeen && mounted) {
        // Wait briefly after mounting for smooth initial render
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted && !_isOpen) {
          setState(() {
            _isPlayingPeek = true;
          });
          _peekController.forward().then((_) {
            if (mounted) {
              setState(() {
                _isPlayingPeek = false;
              });
            }
          });
          await prefs.setBool(_peekPrefKey, true);
        }
      }
    } catch (_) {}
  }

  void _dismissPeekEarly() {
    if (_isPlayingPeek) {
      _peekController.stop();
      _isPlayingPeek = false;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_peekPrefKey, true);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _menuAnimController.dispose();
    _peekController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    _dismissPeekEarly();
    HapticFeedback.lightImpact();
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (_isOpen) return;
    setState(() {
      _isOpen = true;
    });
    Provider.of<FeedProvider>(context, listen: false).fetchAllUnseenCounts();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _menuAnimController.forward();
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    setState(() {
      _isOpen = false;
    });
    _menuAnimController.reverse().then((_) {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // Fullscreen invisible barrier to dismiss when tapped outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _closeDropdown();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Anchored Menu floating directly below title trigger
            Positioned(
              width: 260,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 44),
                child: FadeTransition(
                  opacity: _menuFade,
                  child: ScaleTransition(
                    scale: _menuScale,
                    alignment: Alignment.topLeft,
                    child: SlideTransition(
                      position: _menuSlide,
                      child: Material(
                        color: Colors.transparent,
                        child: _buildMenuCard(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuCard(BuildContext buildContext) {
    final customNetProvider = Provider.of<CustomNetworkProvider>(buildContext);
    final feedProvider = Provider.of<FeedProvider>(buildContext);
    final myNetworks = customNetProvider.myNetworks;
    final isCustomActive = widget.activeCustomNetwork != null;
    final activeCustomId = widget.activeCustomNetwork?.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Built-in Feeds
                for (final net in DiscordNetworkRailDrawer.existingNetworks) ...[
                  _buildMenuItem(
                    iconWidget: Icon(
                      net.icon,
                      size: 18,
                      color: (!isCustomActive && widget.currentFilter == net.filter)
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    title: net.name,
                    isActive: !isCustomActive && widget.currentFilter == net.filter,
                    unseenCount: feedProvider.getUnseenCountForScope(
                      _scopeForFilter(net.filter),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSelectFilter?.call(net.filter);
                      _closeDropdown();
                    },
                  ),
                ],

                // Subtle sleek divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),

                // 2. Custom User Networks (if any)
                if (myNetworks.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: myNetworks.length,
                      itemBuilder: (ctx, index) {
                        final customNet = myNetworks[index];
                        final isThisActive =
                            isCustomActive && activeCustomId == customNet.id;

                        return _buildMenuItem(
                          iconWidget: Text(
                            customNet.iconEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          title: customNet.name,
                          isActive: isThisActive,
                          accentColor: customNet.color,
                          memberCount: isThisActive ? null : customNet.memberCount,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onSelectCustomNetwork?.call(customNet);
                            _closeDropdown();
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ],

                // 3. "+ New Network" Action
                BounceTap(
                  scaleDown: 0.97,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _closeDropdown();
                    CreateCustomNetworkSheet.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'New Network',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required Widget iconWidget,
    required String title,
    required bool isActive,
    int unseenCount = 0,
    int? memberCount,
    String? trailingBadgeText,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final effectiveColor = accentColor ?? context.accentPrimary;

    return BounceTap(
      scaleDown: 0.97,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Squircle icon box
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.16)
                    : context.surfaceSecondary,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 10),

            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Active indicator OR unseen count badge OR member count badge
            if (isActive) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'active',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (unseenCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.accentPrimary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$unseenCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else if (memberCount != null && memberCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 12,
                      color: effectiveColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      '$memberCount',
                      style: TextStyle(
                        color: effectiveColor.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (trailingBadgeText != null) ...[
              Text(
                trailingBadgeText,
                style: TextStyle(
                  color: effectiveColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _scopeForFilter(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.global:
        return 'global';
      case FeedFilter.innerCircle:
        return 'inner_circle';
      case FeedFilter.fullNetwork:
        return 'network';
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);
    final isCustomActive = widget.activeCustomNetwork != null;
    final customNet = widget.activeCustomNetwork;
    final activeNetwork =
        DiscordNetworkRailDrawer.getNetworkData(widget.currentFilter);

    final feedName = isCustomActive
        ? (customNet?.name ?? 'Feed')
        : activeNetwork.name;

    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedBuilder(
        animation: Listenable.merge([_peekScale, _peekGlow]),
        builder: (context, child) {
          final scale = _isPlayingPeek ? _peekScale.value : 1.0;
          final glowVal = _isPlayingPeek ? _peekGlow.value : 0.0;

          return Transform.scale(
            scale: scale,
            child: BounceTap(
              scaleDown: 0.94,
              onTap: _toggleDropdown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: glowVal > 0.05
                        ? Colors.white.withValues(alpha: 0.25 * glowVal)
                        : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: [
                    if (glowVal > 0.05)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.12 * glowVal),
                        blurRadius: 14 * glowVal,
                        spreadRadius: 2 * glowVal,
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Squircle icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: isCustomActive
                            ? Text(
                                customNet!.iconEmoji,
                                style: const TextStyle(fontSize: 16),
                              )
                            : Icon(
                                activeNetwork.icon,
                                size: 17,
                                color: Colors.white,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Feed Name
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        feedName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Animated Chevron (▾ smoothly flips to ▴)
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),

                    // Custom Network Member Count Pill
                    if (isCustomActive && customNet != null) ...[
                      const SizedBox(width: 8),
                      BounceTap(
                        scaleDown: 0.9,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          NetworkMembersSheet.show(context, customNet);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: customNet.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: customNet.color.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add_rounded,
                                  size: 12, color: customNet.color),
                              const SizedBox(width: 3.5),
                              Text(
                                '${customNet.memberCount}',
                                style: TextStyle(
                                  color: customNet.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Unseen badge for current active feed
                    if (!isCustomActive && feedProvider.unseenCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.accentPrimary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          "${feedProvider.unseenCount} new",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
