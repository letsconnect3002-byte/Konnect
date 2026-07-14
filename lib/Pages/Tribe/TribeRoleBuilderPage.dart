import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/tribe_provider.dart';
import 'package:connect/Models/mafia_role_details.dart';

class TribeRoleBuilderPage extends StatefulWidget {
  final String tribeId;

  const TribeRoleBuilderPage({
    super.key,
    required this.tribeId,
  });

  @override
  State<TribeRoleBuilderPage> createState() => _TribeRoleBuilderPageState();
}

class _TribeRoleBuilderPageState extends State<TribeRoleBuilderPage> {
  final _roleNameController = TextEditingController();
  final _iconController = TextEditingController();
  final _colorController = TextEditingController();

  static const List<String> availableColors = [
    '#FFFFFF',
    '#FF5B5B',
    '#5B9AFF',
    '#C55BFF',
    '#5BFFEB',
    '#FFE75B',
    '#FF5BE7',
    '#61FF5B',
    '#FF9F5B',
    '#1E1F22'
  ];

  bool _manageMembers = false;
  bool _manageRoles = false;
  bool _editTribe = false;
  bool _deleteTribe = false;
  bool _inviteMembers = false;
  bool _viewActivityLog = false;
  bool _postMessages = false;
  String? _expandedRoleId;

  // void _resetFields() {
  //   _roleNameController.clear();
  //   _iconController.text = '';
  //   _colorController.text = '#FFFFFF';
  //   _manageMembers = false;
  //   _manageRoles = false;
  //   _editTribe = false;
  //   _deleteTribe = false;
  // }

  // void _showCreateRoleDialog(BuildContext context) {
  //   _resetFields();
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setDlgState) {
  //           return Dialog(
  //             backgroundColor: Colors.transparent,
  //             elevation: 0,
  //             child: GlassmorphicContainer(
  //               borderRadius: BorderRadius.circular(24),
  //               padding: const EdgeInsets.all(20),
  //               child: SingleChildScrollView(
  //                 child: Column(
  //                   mainAxisSize: MainAxisSize.min,
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text("Create Custom Role",
  //                         style: context.screenHeading.copyWith(
  //                             fontWeight: FontWeight.bold, fontSize: 18)),
  //                     const SizedBox(height: 16),
  //                     TextField(
  //                       controller: _roleNameController,
  //                       style: const TextStyle(color: Colors.white),
  //                       decoration: InputDecoration(
  //                         labelText: "Role Name",
  //                         labelStyle: TextStyle(
  //                             color: context.textSecondary, fontSize: 13),
  //                         fillColor: context.surfaceSecondary,
  //                         filled: true,
  //                         border: OutlineInputBorder(
  //                           borderRadius: BorderRadius.circular(12),
  //                           borderSide: BorderSide(color: context.borderMuted),
  //                         ),
  //                         enabledBorder: OutlineInputBorder(
  //                           borderRadius: BorderRadius.circular(12),
  //                           borderSide: BorderSide(color: context.borderMuted),
  //                         ),
  //                         focusedBorder: OutlineInputBorder(
  //                           borderRadius: BorderRadius.circular(12),
  //                           borderSide:
  //                               BorderSide(color: context.accentSecondary),
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(height: 16),
  //                     const Text("Select Role Color",
  //                         style: TextStyle(
  //                             color: Colors.white70,
  //                             fontSize: 12,
  //                             fontWeight: FontWeight.bold)),
  //                     const SizedBox(height: 8),
  //                     SizedBox(
  //                       height: 40,
  //                       child: ListView.builder(
  //                         scrollDirection: Axis.horizontal,
  //                         itemCount: availableColors.length,
  //                         itemBuilder: (context, idx) {
  //                           final colorHex = availableColors[idx];
  //                           final color = Color(
  //                               int.parse(colorHex.replaceAll('#', '0xFF')));
  //                           final isSel = _colorController.text.toUpperCase() ==
  //                               colorHex.toUpperCase();
  //                           return GestureDetector(
  //                             onTap: () {
  //                               setDlgState(() {
  //                                 _colorController.text = colorHex;
  //                               });
  //                             },
  //                             child: Container(
  //                               margin: const EdgeInsets.only(right: 8),
  //                               width: 36,
  //                               height: 36,
  //                               decoration: BoxDecoration(
  //                                 color: color,
  //                                 shape: BoxShape.circle,
  //                                 border: Border.all(
  //                                   color:
  //                                       isSel ? Colors.white : Colors.white24,
  //                                   width: isSel ? 2.5 : 1,
  //                                 ),
  //                                 boxShadow: isSel
  //                                     ? [
  //                                         BoxShadow(
  //                                           color: color.withValues(alpha: 0.4),
  //                                           blurRadius: 6,
  //                                           spreadRadius: 1,
  //                                         )
  //                                       ]
  //                                     : null,
  //                               ),
  //                             ),
  //                           );
  //                         },
  //                       ),
  //                     ),
  //                     const SizedBox(height: 20),
  //                     const Text("Permissions",
  //                         style: TextStyle(
  //                             color: Colors.white70,
  //                             fontSize: 12,
  //                             fontWeight: FontWeight.bold)),
  //                     const SizedBox(height: 4),
  //                     Material(
  //                       color: Colors.transparent,
  //                       child: CheckboxListTile(
  //                         contentPadding: EdgeInsets.zero,
  //                         title: const Text("Manage Members",
  //                             style:
  //                                 TextStyle(color: Colors.white, fontSize: 13)),
  //                         value: _manageMembers,
  //                         activeColor: context.accentSecondary,
  //                         onChanged: (val) {
  //                           setDlgState(() {
  //                             _manageMembers = val ?? false;
  //                           });
  //                         },
  //                       ),
  //                     ),
  //                     Material(
  //                       color: Colors.transparent,
  //                       child: CheckboxListTile(
  //                         contentPadding: EdgeInsets.zero,
  //                         title: const Text("Manage Roles",
  //                             style:
  //                                 TextStyle(color: Colors.white, fontSize: 13)),
  //                         value: _manageRoles,
  //                         activeColor: context.accentSecondary,
  //                         onChanged: (val) {
  //                           setDlgState(() {
  //                             _manageRoles = val ?? false;
  //                           });
  //                         },
  //                       ),
  //                     ),
  //                     Material(
  //                       color: Colors.transparent,
  //                       child: CheckboxListTile(
  //                         contentPadding: EdgeInsets.zero,
  //                         title: const Text("Edit Mafia",
  //                             style:
  //                                 TextStyle(color: Colors.white, fontSize: 13)),
  //                         value: _editTribe,
  //                         activeColor: context.accentSecondary,
  //                         onChanged: (val) {
  //                           setDlgState(() {
  //                             _editTribe = val ?? false;
  //                           });
  //                         },
  //                       ),
  //                     ),
  //                     Material(
  //                       color: Colors.transparent,
  //                       child: CheckboxListTile(
  //                         contentPadding: EdgeInsets.zero,
  //                         title: const Text("Delete Mafia",
  //                             style:
  //                                 TextStyle(color: Colors.white, fontSize: 13)),
  //                         value: _deleteTribe,
  //                         activeColor: context.accentSecondary,
  //                         onChanged: (val) {
  //                           setDlgState(() {
  //                             _deleteTribe = val ?? false;
  //                           });
  //                         },
  //                       ),
  //                     ),
  //                     const SizedBox(height: 24),
  //                     Row(
  //                       mainAxisAlignment: MainAxisAlignment.end,
  //                       children: [
  //                         TextButton(
  //                           child: const Text("Cancel",
  //                               style: TextStyle(color: Colors.white70)),
  //                           onPressed: () => Navigator.pop(context),
  //                         ),
  //                         const SizedBox(width: 12),
  //                         ElevatedButton(
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: context.accentSecondary,
  //                             foregroundColor: Colors.white,
  //                             shape: RoundedRectangleBorder(
  //                                 borderRadius: BorderRadius.circular(10)),
  //                           ),
  //                           child: const Text("Create",
  //                               style: TextStyle(fontWeight: FontWeight.bold)),
  //                           onPressed: () async {
  //                             final provider = Provider.of<TribeProvider>(
  //                                 context,
  //                                 listen: false);
  //                             final name = _roleNameController.text.trim();
  //                             if (name.isEmpty) return;

  //                             final permissions = {
  //                               'manage_members': _manageMembers,
  //                               'manage_roles': _manageRoles,
  //                               'edit_tribe': _editTribe,
  //                               'delete_tribe': _deleteTribe,
  //                             };

  //                             try {
  //                               await provider.createCustomRole(
  //                                 widget.tribeId,
  //                                 name,
  //                                 '',
  //                                 _colorController.text.trim(),
  //                                 permissions,
  //                               );
  //                               if (context.mounted) Navigator.pop(context);
  //                             } catch (e) {
  //                               ScaffoldMessenger.of(context).showSnackBar(
  //                                 SnackBar(
  //                                     content:
  //                                         Text("Failed to create role: $e")),
  //                               );
  //                             }
  //                           },
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  void _showEditRoleDialog(BuildContext context, Map<String, dynamic> role) {
    _roleNameController.text = role['name'] ?? '';
    _iconController.text = '';
    _colorController.text = role['color'] ?? '#FFFFFF';

    final perms = role['permissions'] is Map ? role['permissions'] as Map : {};
    _manageMembers = perms['manage_members'] == true;
    _manageRoles = perms['manage_roles'] == true;
    _editTribe = perms['edit_tribe'] == true;
    _deleteTribe = perms['delete_tribe'] == true;
    _inviteMembers = perms['invite_members'] == true;
    _viewActivityLog = perms['view_activity_log'] == true;
    _postMessages = perms['post_messages'] == true;

    final bool isSystemRole = [
      'don',
      'consigliere',
      'underboss',
      'capo',
      'soldier',
      'associate'
    ].contains(role['slug']);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: GlassmorphicContainer(
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Edit Role: ${role['name']}",
                          style: context.screenHeading.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      if (!isSystemRole) ...[
                        TextField(
                          controller: _roleNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Role Name",
                            labelStyle: TextStyle(
                                color: context.textSecondary, fontSize: 13),
                            fillColor: context.surfaceSecondary,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: context.borderMuted),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: context.borderMuted),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: context.accentSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text("Select Role Color",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: availableColors.length,
                            itemBuilder: (context, idx) {
                              final colorHex = availableColors[idx];
                              final color = Color(
                                  int.parse(colorHex.replaceAll('#', '0xFF')));
                              final isSel =
                                  _colorController.text.toUpperCase() ==
                                      colorHex.toUpperCase();
                              return GestureDetector(
                                onTap: () {
                                  setDlgState(() {
                                    _colorController.text = colorHex;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isSel ? Colors.white : Colors.white24,
                                      width: isSel ? 2.5 : 1,
                                    ),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color:
                                                  color.withValues(alpha: 0.4),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Text("Permissions",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Manage Members",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: _manageMembers,
                          activeColor: context.accentSecondary,
                          onChanged: isSystemRole && role['slug'] == 'don'
                              ? null
                              : (val) {
                                  setDlgState(() {
                                    _manageMembers = val ?? false;
                                  });
                                },
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Manage Roles",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: role['slug'] == 'don' ? _manageRoles : false,
                          activeColor: context.accentSecondary,
                          onChanged: null, // Strictly read-only for all roles to enforce that only Don has manage_roles
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Edit Mafia",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: _editTribe,
                          activeColor: context.accentSecondary,
                          onChanged: isSystemRole && role['slug'] == 'don'
                              ? null
                              : (val) {
                                  setDlgState(() {
                                    _editTribe = val ?? false;
                                  });
                                },
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Delete Mafia",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: role['slug'] == 'don' ? _deleteTribe : false,
                          activeColor: context.accentSecondary,
                          onChanged: null, // Strictly read-only for all roles to enforce that only Don has delete_tribe
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Invite Members",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: _inviteMembers,
                          activeColor: context.accentSecondary,
                          onChanged: isSystemRole && role['slug'] == 'don'
                              ? null
                              : (val) {
                                  setDlgState(() {
                                    _inviteMembers = val ?? false;
                                  });
                                },
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("View Activity Log",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: _viewActivityLog,
                          activeColor: context.accentSecondary,
                          onChanged: isSystemRole && role['slug'] == 'don'
                              ? null
                              : (val) {
                                  setDlgState(() {
                                    _viewActivityLog = val ?? false;
                                  });
                                },
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Post Messages",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                          value: _postMessages,
                          activeColor: context.accentSecondary,
                          onChanged: isSystemRole && role['slug'] == 'don'
                              ? null
                              : (val) {
                                  setDlgState(() {
                                    _postMessages = val ?? false;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text("Cancel",
                                style: TextStyle(color: Colors.white70)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.accentSecondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Save",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final provider = Provider.of<TribeProvider>(
                                  context,
                                  listen: false);
                              final name = _roleNameController.text.trim();
                              if (name.isEmpty) return;

                              final permissions = {
                                'manage_members': _manageMembers,
                                'manage_roles': role['slug'] == 'don' ? _manageRoles : false,
                                'edit_tribe': _editTribe,
                                'delete_tribe': role['slug'] == 'don' ? _deleteTribe : false,
                                'invite_members': _inviteMembers,
                                'view_activity_log': _viewActivityLog,
                                'post_messages': _postMessages,
                              };

                              final updates = isSystemRole
                                  ? {'permissions': permissions}
                                  : {
                                      'name': name,
                                      'icon': '',
                                      'color': _colorController.text.trim(),
                                      'permissions': permissions,
                                    };

                              try {
                                await provider.updateCustomRole(widget.tribeId,
                                    role['id'] as String, updates);
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to save: $e")),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tribeProvider = Provider.of<TribeProvider>(context);
    final roles = tribeProvider.getRoles(widget.tribeId);

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        title: Text("Mafia Roles",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.add_rounded, color: Colors.white),
          //   onPressed: () => _showCreateRoleDialog(context),
          // ),
        ],
      ),
      body: roles.isEmpty
          ? Center(
              child: Text("No roles defined.",
                  style: TextStyle(color: context.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final role = roles[index];
                final slug = role['slug']?.toString() ?? '';
                final roleId = role['id']?.toString() ?? '';
                final isExpanded = _expandedRoleId == roleId;
                final roleDetails = MafiaRoleDetails.getForSlug(slug);
                final displayTitle =
                    role['name']?.toString() ?? roleDetails.title;
                final isSystem = [
                  'don',
                  'consigliere',
                  'underboss',
                  'capo',
                  'soldier',
                  'associate'
                ].contains(slug);
                final roleColorStr = role['color']?.toString() ?? '#FFFFFF';
                final roleColor =
                    Color(int.parse(roleColorStr.replaceAll('#', '0xFF')));

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: context.surfacePrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          onTap: () {
                            setState(() {
                              _expandedRoleId = isExpanded ? null : roleId;
                            });
                          },
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: roleColor.withValues(alpha: 0.2),
                                  width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              role['icon']?.toString() ?? roleDetails.icon,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                              if (isSystem) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.accentSecondary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "SYSTEM",
                                    style: TextStyle(
                                      color: context.accentSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 8,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // subtitle: Padding(
                          //   padding: const EdgeInsets.only(top: 4.0),
                          //   child: Text(
                          //     roleColorStr,
                          //     style: TextStyle(
                          //       color: roleColor,
                          //       fontSize: 11,
                          //       fontFamily: 'Inter',
                          //     ),
                          //   ),
                          // ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: Colors.white70, size: 18),
                                onPressed: () =>
                                    _showEditRoleDialog(context, role),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              if (!isSystem) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () async {
                                    try {
                                      await tribeProvider.deleteCustomRole(
                                          widget.tribeId, role['id'] as String);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Failed to delete role: $e")),
                                      );
                                    }
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: isExpanded
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                      left: 74, right: 16, bottom: 16),
                                  child: Text(
                                    roleDetails.uxProfile.isNotEmpty
                                        ? roleDetails.uxProfile
                                        : "No description details configured.",
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
