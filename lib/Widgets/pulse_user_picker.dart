import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Config/app_theme.dart';

class PulseUserPicker extends StatefulWidget {
  final List<Map<String, dynamic>> connections;
  final List<int> initialSelectedIds;

  const PulseUserPicker({
    super.key,
    required this.connections,
    required this.initialSelectedIds,
  });

  @override
  State<PulseUserPicker> createState() => _PulseUserPickerState();
}

class _PulseUserPickerState extends State<PulseUserPicker> {
  final List<int> _selectedIds = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.connections.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final profession = (c['profession'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || profession.contains(query);
    }).toList();

    return Material(
      color: context.surfacePrimary,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.surfaceSecondary),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  "Hide Pulse From",
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, _selectedIds);
                  },
                  child: Text(
                    "Done",
                    style: TextStyle(
                      color: context.accentSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: context.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: TextStyle(color: context.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: "Search connections...",
                        hintStyle: TextStyle(color: context.textMuted, fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      child: Icon(Icons.close_rounded, color: context.textMuted, size: 16),
                    ),
                ],
              ),
            ),
          ),

          // Horizontal list of selected connections as chips
          if (_selectedIds.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _selectedIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final id = _selectedIds[index];
                  final conn = widget.connections.firstWhere(
                    (c) => c['id'] == id,
                    orElse: () => {'name': 'User', 'avatarUrl': ''},
                  );
                  final name = conn['name'] ?? 'User';
                  final avatar = conn['avatarUrl'] ?? '';

                  return InputChip(
                    avatar: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      backgroundColor: context.surfaceSecondary,
                      child: avatar.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '',
                              style: TextStyle(color: context.textPrimary, fontSize: 9),
                            )
                          : null,
                    ),
                    label: Text(
                      name,
                      style: TextStyle(color: context.textPrimary, fontSize: 12),
                    ),
                    backgroundColor: context.surfaceSecondary,
                    deleteIconColor: context.textSecondary,
                    onDeleted: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedIds.remove(id);
                      });
                    },
                  );
                },
              ),
            ),

          const Divider(height: 1, color: Colors.white10),

          // Connections list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? "No connections found." : "No matching connections.",
                      style: TextStyle(color: context.textMuted, fontSize: 13.5),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final conn = filtered[index];
                      final id = conn['id'] as int;
                      final name = conn['name'] ?? 'Unknown';
                      final profession = conn['profession'] ?? '';
                      final avatar = conn['avatarUrl'] ?? '';
                      final isSelected = _selectedIds.contains(id);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          backgroundColor: context.surfaceSecondary,
                          child: avatar.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '',
                                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: profession.isNotEmpty
                            ? Text(
                                profession,
                                style: TextStyle(color: context.textSecondary, fontSize: 12),
                              )
                            : null,
                        trailing: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? context.accentSecondary : context.textMuted,
                          size: 22,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
  }
}
