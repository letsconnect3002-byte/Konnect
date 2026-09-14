import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Models/custom_network.dart';
import 'package:connect/Providers/custom_network_provider.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Widgets/create_custom_network_sheet.dart';

/// Representation of an existing built-in network circle.
class NetworkItemData {
  final FeedFilter filter;
  final String name;
  final String subtitle;
  final IconData icon;

  const NetworkItemData({
    required this.filter,
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

/// Frosted Glass Navigation Rail Drawer for Networks.
///
/// Refined 74px Apple-inspired floating dock rail displaying built-in networks,
/// custom user networks, and a dedicated '+' creation squircle.
class DiscordNetworkRailDrawer extends StatelessWidget {
  final FeedFilter currentFilter;
  final ValueChanged<FeedFilter>? onSelectFilter;
  final ValueChanged<CustomNetwork>? onSelectCustomNetwork;

  const DiscordNetworkRailDrawer({
    super.key,
    required this.currentFilter,
    this.onSelectFilter,
    this.onSelectCustomNetwork,
  });

  // The 3 built-in networks in the app (Unified Monochrome)
  static const List<NetworkItemData> existingNetworks = [
    NetworkItemData(
      filter: FeedFilter.global,
      name: 'Global',
      subtitle: 'Public posts from everyone',
      icon: Icons.language_rounded,
    ),
    NetworkItemData(
      filter: FeedFilter.fullNetwork,
      name: 'Network',
      subtitle: '1st & 2nd degree connections',
      icon: Icons.public_rounded,
    ),
    NetworkItemData(
      filter: FeedFilter.innerCircle,
      name: 'Inner Circle',
      subtitle: 'Direct 1st degree connections only',
      icon: Icons.people_alt_rounded,
    ),
  ];

  static NetworkItemData getNetworkData(FeedFilter filter) {
    return existingNetworks.firstWhere(
      (n) => n.filter == filter,
      orElse: () => existingNetworks[1],
    );
  }

  void _handleSelectBuiltinNetwork(BuildContext context, FeedFilter filter) {
    HapticFeedback.selectionClick();
    final customNetProvider =
        Provider.of<CustomNetworkProvider>(context, listen: false);
    customNetProvider.selectCustomNetwork(null);
    onSelectFilter?.call(filter);
    Navigator.of(context).maybePop();
  }

  void _handleSelectCustomNetwork(BuildContext context, CustomNetwork network) {
    HapticFeedback.selectionClick();
    final customNetProvider =
        Provider.of<CustomNetworkProvider>(context, listen: false);
    customNetProvider.selectCustomNetwork(network);
    onSelectCustomNetwork?.call(network);
    Navigator.of(context).maybePop();
  }

  void _handleOpenCreateNetwork(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
    CreateCustomNetworkSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final customNetProvider = Provider.of<CustomNetworkProvider>(context);
    final feedProvider = Provider.of<FeedProvider>(context);
    final myNetworks = customNetProvider.myNetworks;
    final activeCustomNetwork = feedProvider.activeCustomNetwork;
    final bool isCustomActive = activeCustomNetwork != null;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 76,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfacePrimary.withValues(alpha: 0.88),
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(24)),
                  border: Border.all(
                    color: AppColors.borderMuted,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 32,
                      offset: const Offset(6, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Top Hub Icon
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: AppColors.textSecondary,
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 32,
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Scrollable Squircle Icons Rail
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // 1. Built-in Networks (Monochrome White Active)
                          for (final network in existingNetworks) ...[
                            _buildRailSquircleItem(
                              context: context,
                              name: network.name,
                              iconWidget: Icon(
                                network.icon,
                                size: 21,
                                color: (!isCustomActive &&
                                        currentFilter == network.filter)
                                    ? Colors.black
                                    : AppColors.textSecondary,
                              ),
                              isSelected: !isCustomActive &&
                                  currentFilter == network.filter,
                              onTap: () => _handleSelectBuiltinNetwork(
                                  context, network.filter),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Divider between built-in and custom networks
                          if (myNetworks.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 1.5,
                                  decoration: BoxDecoration(
                                    color: AppColors.borderSubtle,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // 2. Custom User Networks
                          for (final net in myNetworks) ...[
                            _buildRailSquircleItem(
                              context: context,
                              name: net.name,
                              iconWidget: Text(
                                net.iconEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              isSelected: isCustomActive &&
                                  activeCustomNetwork.id == net.id,
                              onTap: () =>
                                  _handleSelectCustomNetwork(context, net),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Divider before '+' Create Network button
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  color: AppColors.borderSubtle,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),

                          // 3. '+' Create Network Squircle Button
                          _buildCreateNetworkButton(context),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailSquircleItem({
    required BuildContext context,
    required String name,
    required Widget iconWidget,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: name,
      preferBelow: false,
      verticalOffset: 26,
      textStyle: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Left indicator pill (Apple-style white rounded bar)
            Positioned(
              left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 5.5,
                height: isSelected ? 36 : 0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3.5),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),

            // Squircle icon container
            Center(
              child: BounceTap(
                scaleDown: 0.90,
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        isSelected ? Colors.white : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(isSelected ? 14 : 23),
                    border: Border.all(
                      color: isSelected ? Colors.white : AppColors.borderSubtle,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: iconWidget),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNetworkButton(BuildContext context) {
    return Tooltip(
      message: 'Create Network',
      preferBelow: false,
      verticalOffset: 26,
      textStyle: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SizedBox(
        height: 50,
        child: Center(
          child: BounceTap(
            scaleDown: 0.90,
            onTap: () => _handleOpenCreateNetwork(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
