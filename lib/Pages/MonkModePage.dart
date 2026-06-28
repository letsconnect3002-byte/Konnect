import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/monk_mode_provider.dart';
import 'package:connect/Config/app_theme.dart';

class MonkDurationOption {
  final String label;
  final Duration duration;

  const MonkDurationOption(this.label, this.duration);
}

class MonkModePage extends StatefulWidget {
  const MonkModePage({super.key});

  @override
  State<MonkModePage> createState() => _MonkModePageState();
}

class _MonkModePageState extends State<MonkModePage> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _countdownTimer;

  final List<MonkDurationOption> _durationOptions = const [
    MonkDurationOption("10s (Demo)", Duration(seconds: 10)),
    MonkDurationOption("15m", Duration(minutes: 15)),
    MonkDurationOption("1h", Duration(hours: 1)),
    MonkDurationOption("8h", Duration(hours: 8)),
    MonkDurationOption("Custom...", Duration(minutes: -2)), // special indicator
    MonkDurationOption("Indefinite", Duration.zero),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ConnectionProvider>(context, listen: false)
            .fetchConnections();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final monkMode = Provider.of<MonkModeProvider>(context, listen: false);
      if (monkMode.enabled && monkMode.deactivateAt != null) {
        setState(() {}); // trigger rebuild to update the countdown ticking text
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final hour = localDateTime.hour;
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return "$displayHour:$minute $period";
  }

  String _formatDurationRemaining(DateTime? deactivateAt) {
    if (deactivateAt == null) return "";
    final now = DateTime.now();
    final diff = deactivateAt.toLocal().difference(now);
    if (diff.isNegative) return "0s remaining";

    if (diff.inHours > 0) {
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return "${hours}h ${minutes}m ${seconds}s remaining";
    } else if (diff.inMinutes > 0) {
      final minutes = diff.inMinutes.toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return "${minutes}m ${seconds}s remaining";
    } else {
      return "${diff.inSeconds}s remaining";
    }
  }

  void _showCustomDurationDialog(MonkModeProvider monkMode, int previousIndex) {
    int selectedDays = 0;
    int selectedHours = 0;
    int selectedMinutes = 0;

    // Parse current custom duration if it exists
    if (monkMode.customDurationMinutes != null) {
      int total = monkMode.customDurationMinutes!;
      selectedDays = total ~/ (24 * 60);
      selectedHours = (total % (24 * 60)) ~/ 60;
      selectedMinutes = total % 60;
    } else {
      // Default: 1 hour silence
      selectedDays = 0;
      selectedHours = 1;
      selectedMinutes = 0;
    }

    selectedDays = selectedDays.clamp(0, 7);
    selectedHours = selectedHours.clamp(0, 23);
    selectedMinutes = selectedMinutes.clamp(0, 59);

    final FixedExtentScrollController dayController =
        FixedExtentScrollController(initialItem: selectedDays);
    final FixedExtentScrollController hourController =
        FixedExtentScrollController(initialItem: selectedHours);
    final FixedExtentScrollController minuteController =
        FixedExtentScrollController(initialItem: selectedMinutes);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isDurationZero =
                selectedDays == 0 && selectedHours == 0 && selectedMinutes == 0;

            return AlertDialog(
              backgroundColor: context.surfacePrimary,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusPremiumCard),
                side: BorderSide(color: context.surfaceSecondary, width: 1.5),
              ),
              title: Text(
                "Custom Silence Time",
                style:
                    context.screenHeading.copyWith(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Scroll to configure how long notifications are blocked.",
                    style: context.bodyText
                        .copyWith(color: context.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: context.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // Days picker
                        Expanded(
                          child: CupertinoTheme(
                            data: const CupertinoThemeData(
                              brightness: Brightness.dark,
                            ),
                            child: CupertinoPicker(
                              scrollController: dayController,
                              itemExtent: 36,
                              backgroundColor: Colors.transparent,
                              onSelectedItemChanged: (int val) {
                                HapticFeedback.selectionClick();
                                setDialogState(() {
                                  selectedDays = val;
                                });
                              },
                              children: List.generate(8, (int index) {
                                return Center(
                                  child: Text(
                                    "$index ${index == 1 ? 'day' : 'days'}",
                                    style: context.bodyText.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        // Hours picker
                        Expanded(
                          child: CupertinoTheme(
                            data: const CupertinoThemeData(
                              brightness: Brightness.dark,
                            ),
                            child: CupertinoPicker(
                              scrollController: hourController,
                              itemExtent: 36,
                              backgroundColor: Colors.transparent,
                              onSelectedItemChanged: (int val) {
                                HapticFeedback.selectionClick();
                                setDialogState(() {
                                  selectedHours = val;
                                });
                              },
                              children: List.generate(24, (int index) {
                                return Center(
                                  child: Text(
                                    "$index ${index == 1 ? 'hr' : 'hrs'}",
                                    style: context.bodyText.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        // Minutes picker
                        Expanded(
                          child: CupertinoTheme(
                            data: const CupertinoThemeData(
                              brightness: Brightness.dark,
                            ),
                            child: CupertinoPicker(
                              scrollController: minuteController,
                              itemExtent: 36,
                              backgroundColor: Colors.transparent,
                              onSelectedItemChanged: (int val) {
                                HapticFeedback.selectionClick();
                                setDialogState(() {
                                  selectedMinutes = val;
                                });
                              },
                              children: List.generate(60, (int index) {
                                return Center(
                                  child: Text(
                                    "$index ${index == 1 ? 'min' : 'mins'}",
                                    style: context.bodyText.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(dialogContext);
                    // Reset selected index back to previous
                    monkMode.setMonkMode(
                      enabled: monkMode.enabled,
                      selectedDurationIndex: previousIndex,
                    );
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDurationZero
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(dialogContext);

                          final totalMins = (selectedDays * 24 * 60) +
                              (selectedHours * 60) +
                              selectedMinutes;
                          final customDuration = Duration(minutes: totalMins);

                          monkMode.setMonkMode(
                            enabled: true,
                            deactivateAt: DateTime.now().add(customDuration),
                            selectedDurationIndex: 4,
                            customDurationMinutes: totalMins,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentPrimary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        context.surfaceSecondary.withValues(alpha: 0.5),
                    disabledForegroundColor: context.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Set",
                    style: context.bodyText.copyWith(
                      color: isDurationZero ? context.textMuted : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getAvatarUrl(String name, String? existingUrl) {
    if (existingUrl != null &&
        existingUrl.isNotEmpty &&
        existingUrl.startsWith('http')) {
      return existingUrl;
    }
    return '';
  }

  Widget _buildFallbackAvatar(String name, double fontSize) {
    final monogram = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    return Center(
      child: Text(
        monogram,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monkMode = context.watch<MonkModeProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final allProfiles = connectionProvider.connections;

    // Detect transition from enabled to disabled to show automatic deactivation SnackBar
    if (monkMode.deactivatedAutomatically) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          monkMode.clearDeactivatedAutomatically();
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Monk Mode deactivated automatically. You are back in the loop!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1C1D22),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.white10, width: 1),
              ),
            ),
          );
        }
      });
    }

    // Filter connections based on search query
    final filteredProfiles = allProfiles.where((profile) {
      final name = (profile['name'] ?? '').toString().toLowerCase();
      final profession = (profile['profession'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || profession.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: SafeArea(
        child: !monkMode.initialized
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.marginStandard),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Premium Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: monkMode.enabled
                                ? context.accentPrimary.withValues(alpha: 0.1)
                                : context.surfaceSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.self_improvement_rounded,
                            size: 28,
                            color: monkMode.enabled
                                ? context.accentPrimary
                                : context.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Monk Mode",
                                style: context.displayHeader,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Silence app noise and focus on what matters.",
                                style: context.bodyText.copyWith(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Master Toggle Card
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: context.surfacePrimary,
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusPremiumCard),
                        border: Border.all(
                          color: monkMode.enabled
                              ? context.accentPrimary.withValues(alpha: 0.35)
                              : context.surfaceSecondary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (monkMode.enabled)
                            BoxShadow(
                              color:
                                  context.accentPrimary.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Monk Mode Status",
                                          style: context.cardTitle.copyWith(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          opacity: monkMode.enabled ? 1.0 : 0.0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: context.accentPrimary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "ACTIVE",
                                              style:
                                                  context.captionText.copyWith(
                                                color: context.accentPrimary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      monkMode.enabled
                                          ? (monkMode.deactivateAt != null
                                              ? "Silent until ${_formatTime(monkMode.deactivateAt!)} (${_formatDurationRemaining(monkMode.deactivateAt)})"
                                              : "Notifications from muted users are blocked.")
                                          : "Monk Mode is off. All notifications are enabled.",
                                      style: context.bodyText.copyWith(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: monkMode.enabled,
                                activeThumbColor: context.accentPrimary,
                                activeTrackColor: context.accentPrimary
                                    .withValues(alpha: 0.3),
                                inactiveThumbColor: context.textSecondary,
                                inactiveTrackColor: context.surfaceSecondary,
                                onChanged: (val) {
                                  HapticFeedback.mediumImpact();
                                  if (val) {
                                    final option = _durationOptions[
                                        monkMode.selectedDurationIndex];
                                    if (option.duration != Duration.zero) {
                                      if (monkMode.selectedDurationIndex == 4) {
                                        if (monkMode.customDurationMinutes !=
                                            null) {
                                          final deactivateAt = DateTime.now()
                                              .add(Duration(
                                                  minutes: monkMode
                                                      .customDurationMinutes!));
                                          monkMode.setMonkMode(
                                            enabled: true,
                                            deactivateAt: deactivateAt,
                                          );
                                        } else {
                                          _showCustomDurationDialog(
                                              monkMode, 5);
                                        }
                                      } else {
                                        final deactivateAt =
                                            DateTime.now().add(option.duration);
                                        monkMode.setMonkMode(
                                          enabled: true,
                                          deactivateAt: deactivateAt,
                                        );
                                      }
                                    } else {
                                      monkMode.setMonkMode(
                                          enabled: true, deactivateAt: null);
                                    }
                                  } else {
                                    monkMode.setMonkMode(
                                        enabled: false, deactivateAt: null);
                                  }
                                },
                              ),
                            ],
                          ),
                          if (monkMode.enabled) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 16),
                            Text(
                              "SILENCE FOR",
                              style: context.captionText.copyWith(
                                color: context.textSecondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _durationOptions.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final option = _durationOptions[index];
                                  final isSelected =
                                      monkMode.selectedDurationIndex == index;
                                  final isCustom = index == 4;

                                  final String labelText;
                                  if (isCustom &&
                                      monkMode.customDurationMinutes != null) {
                                    int total = monkMode.customDurationMinutes!;
                                    int days = total ~/ (24 * 60);
                                    int hours = (total % (24 * 60)) ~/ 60;
                                    int minutes = total % 60;

                                    List<String> parts = [];
                                    if (days > 0) parts.add("${days}d");
                                    if (hours > 0) parts.add("${hours}h");
                                    if (minutes > 0) parts.add("${minutes}m");

                                    labelText =
                                        parts.isEmpty ? "0m" : parts.join(" ");
                                  } else {
                                    labelText = option.label;
                                  }

                                  Widget labelWidget;
                                  if (isCustom) {
                                    final String displayLabel =
                                        monkMode.customDurationMinutes != null
                                            ? "Custom ($labelText)"
                                            : "Custom...";
                                    labelWidget = Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          size: 13,
                                          color: isSelected
                                              ? Colors.black
                                              : context.accentPrimary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          displayLabel,
                                          style: context.captionText.copyWith(
                                            color: isSelected
                                                ? Colors.black
                                                : context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    labelWidget = Text(
                                      labelText,
                                      style: context.captionText.copyWith(
                                        color: isSelected
                                            ? Colors.black
                                            : context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }

                                  final double borderWidth =
                                      isCustom ? 1.5 : 1.0;
                                  final BorderSide borderSide;
                                  if (isSelected) {
                                    borderSide = BorderSide(
                                      color: isCustom
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : context.accentPrimary,
                                      width: borderWidth,
                                    );
                                  } else {
                                    borderSide = BorderSide(
                                      color: isCustom
                                          ? context.accentPrimary
                                              .withValues(alpha: 0.5)
                                          : context.surfaceSecondary,
                                      width: borderWidth,
                                    );
                                  }

                                  final Color chipBgColor =
                                      isCustom && !isSelected
                                          ? context.surfaceSecondary
                                              .withValues(alpha: 0.4)
                                          : context.surfaceSecondary;

                                  return ChoiceChip(
                                    label: labelWidget,
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      HapticFeedback.lightImpact();
                                      if (isCustom) {
                                        _showCustomDurationDialog(monkMode,
                                            monkMode.selectedDurationIndex);
                                      } else {
                                        if (selected) {
                                          if (option.duration !=
                                              Duration.zero) {
                                            final deactivateAt = DateTime.now()
                                                .add(option.duration);
                                            monkMode.setMonkMode(
                                              enabled: monkMode.enabled,
                                              deactivateAt: deactivateAt,
                                              selectedDurationIndex: index,
                                            );
                                          } else {
                                            monkMode.setMonkMode(
                                              enabled: monkMode.enabled,
                                              deactivateAt: null,
                                              selectedDurationIndex: index,
                                            );
                                          }
                                        }
                                      }
                                    },
                                    selectedColor: context.accentPrimary,
                                    backgroundColor: chipBgColor,
                                    checkmarkColor: Colors.black,
                                    showCheckmark: false,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: borderSide,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search field
                    TextField(
                      controller: _searchController,
                      style: context.bodyText,
                      cursorColor: context.accentPrimary,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search connections...",
                        hintStyle:
                            context.bodyText.copyWith(color: context.textMuted),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: context.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: context.textSecondary, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = "";
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: context.surfacePrimary,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusComponent),
                          borderSide:
                              BorderSide(color: context.surfaceSecondary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusComponent),
                          borderSide: BorderSide(
                              color:
                                  context.accentPrimary.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "INDIVIDUAL PREFERENCES",
                                style: context.captionText.copyWith(
                                  color: context.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // if (!monkMode.enabled) ...[
                              //   const SizedBox(height: 2),
                              //   Text(
                              //     "Inactive (default is allowed all when Monk Mode is off)",
                              //     style: context.captionText.copyWith(
                              //       color: context.textMuted,
                              //       fontSize: 9,
                              //       fontWeight: FontWeight.normal,
                              //     ),
                              //     maxLines: 1,
                              //     overflow: TextOverflow.ellipsis,
                              //   ),
                              // ],
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: allProfiles.isEmpty
                                  ? null
                                  : () {
                                      final ids = allProfiles
                                          .map((p) => p['id'] as int)
                                          .toList();
                                      monkMode.muteAll(ids);
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Mute All",
                                style: context.captionText.copyWith(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 12,
                              width: 1,
                              color: context.surfaceSecondary,
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: monkMode.blockedIds.isEmpty
                                  ? null
                                  : () {
                                      monkMode.allowAll();
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Allow All",
                                style: context.captionText.copyWith(
                                  color: context.accentPrimary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Connections List
                    Expanded(
                      child: connectionProvider.state is UserConnectionLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF7C3AED)),
                              ),
                            )
                          : filteredProfiles.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        color: context.textMuted,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? "No connections match your search."
                                            : "No connections found.",
                                        style: context.bodyText.copyWith(
                                            color: context.textSecondary),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filteredProfiles.length,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 100),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 2),
                                  itemBuilder: (context, index) {
                                    final profile = filteredProfiles[index];
                                    final id = profile['id'] as int;
                                    final name = profile['name'] ?? 'Unknown';
                                    final profession =
                                        profile['profession'] ?? '';
                                    final avatarUrl = _getAvatarUrl(
                                        name, profile['avatarUrl']);
                                    final isBlocked =
                                        monkMode.blockedIds.contains(id);

                                    return Opacity(
                                      opacity: monkMode.enabled ? 1.0 : 0.7,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        // decoration: BoxDecoration(
                                        //   color: context.surfacePrimary,
                                        //   borderRadius: BorderRadius.circular(
                                        //       AppDimensions.radiusComponent),
                                        //   border: Border.all(
                                        //     color:
                                        //         (monkMode.enabled && isBlocked)
                                        //             ? Colors.redAccent
                                        //                 .withValues(alpha: 0.15)
                                        //             : context.surfaceSecondary
                                        //                 .withValues(alpha: 0.5),
                                        //     width: 1.0,
                                        //   ),
                                        // ),
                                        child: Row(
                                          children: [
                                            // Avatar
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: (monkMode.enabled &&
                                                          isBlocked)
                                                      ? Colors.redAccent
                                                          .withValues(
                                                              alpha: 0.3)
                                                      : context.accentPrimary
                                                          .withValues(
                                                              alpha: 0.25),
                                                  width: 1.5,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.all(1.0),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xFF1C1D22),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: (avatarUrl.isNotEmpty &&
                                                        avatarUrl
                                                            .startsWith('http'))
                                                    ? Image.network(
                                                        avatarUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            _buildFallbackAvatar(
                                                                name, 16),
                                                      )
                                                    : _buildFallbackAvatar(
                                                        name, 16),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // User info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: context.bodyText
                                                        .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (profession.isNotEmpty)
                                                    Text(
                                                      profession,
                                                      style: context.captionText
                                                          .copyWith(
                                                        color: context
                                                            .textSecondary,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Toggle/State indicator
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      (monkMode.enabled &&
                                                              isBlocked)
                                                          ? "MUTED"
                                                          : "ALLOWED",
                                                      style: context.captionText
                                                          .copyWith(
                                                        color: (monkMode
                                                                    .enabled &&
                                                                isBlocked)
                                                            ? Colors.redAccent
                                                            : (monkMode.enabled
                                                                ? context
                                                                    .accentPrimary
                                                                : context
                                                                    .textSecondary),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    IconButton(
                                                      icon: Icon(
                                                        (monkMode.enabled &&
                                                                isBlocked)
                                                            ? Icons
                                                                .notifications_off_rounded
                                                            : Icons
                                                                .notifications_active_rounded,
                                                        color: (monkMode
                                                                    .enabled &&
                                                                isBlocked)
                                                            ? Colors.redAccent
                                                            : (monkMode.enabled
                                                                ? context
                                                                    .accentPrimary
                                                                : context
                                                                    .textSecondary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5)),
                                                        size: 20,
                                                      ),
                                                      onPressed: () {
                                                        monkMode
                                                            .toggleUserBlock(
                                                                id, !isBlocked);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
