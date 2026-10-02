import 'dart:convert';
import 'package:connect/Pages/IndividualChatPage.dart';
import 'package:connect/Pages/yet_to_be_built_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:connect/Utils/profile_field_filter.dart';
import 'package:connect/Utils/social_launcher.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/services/analytics_service.dart';
import 'package:connect/Models/resume_models.dart';
import 'package:connect/Widgets/resume_sections_widget.dart';
import 'package:connect/Providers/vouch_provider.dart';
import 'package:connect/Widgets/vouch_bottom_sheet.dart';
import 'package:connect/Widgets/vouches_list_widget.dart';
import 'package:connect/Widgets/direct_connection_sheet.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Providers/feed_provider.dart';

class ConnectionProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;
  const ConnectionProfilePage({super.key, required this.profileData});

  @override
  State<ConnectionProfilePage> createState() => _ConnectionProfilePageState();
}

class _ConnectionProfilePageState extends State<ConnectionProfilePage> {
  bool _isLoading = false;
  Map<String, dynamic>? _fieldAssignments;

  late String _name;
  late String _profession;
  late String _company;
  late String _email;
  late String _professionalEmail;
  late String _phoneNumber;
  late String _professionalPhoneNumber;
  late String _bio;
  late String _professionalBio;
  late String _avatarUrl;
  late String _instagram;
  late String _linkedin;
  late String _twitter;
  late String _spotify;
  String _handle = '';
  List<dynamic> _customLinks = [];
  List<ExperienceItem> _experience = [];
  List<EducationItem> _education = [];
  List<String> _skills = [];
  Map<String, String> _casualFields = {};
  Map<String, String> _professionalFields = {};

  Map<String, String> get _activeFields {
    final merged = Map<String, String>.from(_casualFields);
    for (final entry in _professionalFields.entries) {
      if (entry.value.trim().isNotEmpty) {
        merged[entry.key] = entry.value;
      }
    }
    if ((merged['email'] ?? '').isEmpty && _email.isNotEmpty) {
      merged['email'] = _email;
    }
    if ((merged['phoneNumber'] ?? '').isEmpty && _phoneNumber.isNotEmpty) {
      merged['phoneNumber'] = _phoneNumber;
    }
    if ((merged['bio'] ?? '').isEmpty && _bio.isNotEmpty) {
      merged['bio'] = _bio;
    }
    return merged;
  }

  Map<String, String> get _previewFields => _activeFields;

  late final ProfileProvider profileProvider;
  late final ConnectionProvider connectionProvider;
  String _sharedCardPermission = 'both'; // permission context

  int get _targetUserId {
    final idVal = widget.profileData['id'] ??
        widget.profileData['connection_profile_id'] ??
        widget.profileData['user_id'];
    if (idVal is int) return idVal;
    return int.tryParse(idVal?.toString() ?? '0') ?? 0;
  }

  List<String> _mutualIntents = [];

  @override
  void initState() {
    super.initState();
    profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    _loadProfileData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final myUserId = profileProvider.userId;
        if (myUserId != null && _targetUserId != 0) {
          final vProvider = Provider.of<VouchProvider>(context, listen: false);
          vProvider.checkHasVouched(
            voucherId: myUserId,
            voucheeId: _targetUserId,
          );
          vProvider
              .getMutualIntents(
            userId1: myUserId,
            userId2: _targetUserId,
          )
              .then((intents) {
            if (mounted && intents.isNotEmpty) {
              setState(() => _mutualIntents = intents);
            }
          });
        }
      }
    });
  }

  Future<void> _loadProfileData() async {
    final data = widget.profileData;
    final String permission = (data['sharedCard'] ??
            data['shared_card'] ??
            data['sharedCardPermission'] ??
            data['shared_card_permission'] ??
            'casual')
        .toString();
    _sharedCardPermission = permission;

    AnalyticsService.logEvent(
      name: 'profile_viewed',
      parameters: {
        'target_user_id': data['id'] ?? 0,
        'degree': 1,
        'shared_card': permission,
      },
    );

    _fieldAssignments = data['field_assignments'] is Map<String, dynamic>
        ? data['field_assignments'] as Map<String, dynamic>
        : (data['field_assignments'] is String
            ? jsonDecode(data['field_assignments'] as String)
                as Map<String, dynamic>
            : null);
    _name = data['name'] ?? '';
    _profession = data['profession'] ?? '';
    _company = data['company'] ?? '';
    _email = data['email'] ?? '';
    _professionalEmail =
        data['professionalEmail'] ?? data['professional_email'] ?? '';
    _phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? '';
    _professionalPhoneNumber = data['professionalPhoneNumber'] ??
        data['professional_phone_number'] ??
        '';
    _bio = data['bio'] ?? '';
    _professionalBio =
        data['professionalBio'] ?? data['professional_bio'] ?? '';
    _avatarUrl = data['avatarUrl'] ?? data['avatar_url'] ?? '';
    _instagram = data['instagram'] ?? '';
    _linkedin = data['linkedin'] ?? '';
    _twitter = data['twitter'] ?? '';
    _spotify = data['spotify'] ?? '';
    _handle = (data['handle'] ?? '').toString();
    _customLinks = data['custom_links'] != null
        ? List<dynamic>.from(data['custom_links'] as List)
        : [];

    if (data['experience'] != null) {
      final expData = data['experience'] is String
          ? jsonDecode(data['experience'] as String)
          : data['experience'];
      if (expData is List) {
        _experience = expData
            .map((e) => ExperienceItem.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final exp in _experience) {
          if (exp.isCurrent ||
              exp.endDate.trim().toLowerCase() == 'present' ||
              exp.endDate.toLowerCase().contains('present')) {
            if (exp.company.trim().isNotEmpty) {
              _company = exp.company.trim();
              break;
            }
          }
        }
      }
    } else {
      _experience = [];
    }

    if (data['education'] != null) {
      final eduData = data['education'] is String
          ? jsonDecode(data['education'] as String)
          : data['education'];
      if (eduData is List) {
        _education = eduData
            .map((e) => EducationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } else {
      _education = [];
    }

    if (data['skills'] != null) {
      final skillsData = data['skills'] is String
          ? jsonDecode(data['skills'] as String)
          : data['skills'];
      if (skillsData is List) {
        _skills = List<String>.from(skillsData.map((e) => e.toString()));
      }
    } else {
      _skills = [];
    }

    final String initialProfEmail = _professionalEmail;
    final String initialProfPhone = _professionalPhoneNumber;

    _casualFields = {
      'email': _email,
      'phoneNumber': _phoneNumber,
      'instagram': _instagram,
      'linkedin': _linkedin,
      'twitter': _twitter,
      'spotify': _spotify,
      'bio': _bio,
    };
    _professionalFields = {
      'email': initialProfEmail,
      'phoneNumber': initialProfPhone,
      'instagram': _instagram,
      'linkedin': _linkedin,
      'twitter': _twitter,
      'spotify': _spotify,
      'bio': _professionalBio,
    };

    final idToFetch = _targetUserId;
    if (idToFetch != 0) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      try {
        final details = await profileProvider.fetchConnectionDetails(idToFetch);
        final response = details['profile'] as Map<String, dynamic>?;
        _sharedCardPermission =
            details['sharedCardPermission'] as String? ?? 'both';

        if (response != null && mounted) {
          final Map<String, dynamic>? fieldAssignments =
              response['field_assignments'] is Map<String, dynamic>
                  ? response['field_assignments'] as Map<String, dynamic>
                  : (response['field_assignments'] is String
                      ? jsonDecode(response['field_assignments'] as String)
                          as Map<String, dynamic>
                      : null);

          setState(() {
            _fieldAssignments = fieldAssignments;
            if ((response['name'] ?? '').toString().trim().isNotEmpty) {
              _name = response['name'];
            }
            if ((response['avatar_url'] ?? '').toString().trim().isNotEmpty) {
              _avatarUrl = response['avatar_url'];
            }
            if ((response['profession'] ?? '').toString().trim().isNotEmpty) {
              _profession = response['profession'];
            }
            if ((response['company'] ?? '').toString().trim().isNotEmpty) {
              _company = response['company'];
            }
            if ((response['handle'] ?? '').toString().trim().isNotEmpty) {
              _handle = response['handle'];
            }
            _email = ProfileFieldFilter.getVisibleValue(
                'email',
                response['email'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _professionalEmail = ProfileFieldFilter.getVisibleValue(
                'professionalEmail',
                response['professional_email'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _phoneNumber = ProfileFieldFilter.getVisibleValue(
                'phoneNumber',
                response['phone_number'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _professionalPhoneNumber = ProfileFieldFilter.getVisibleValue(
                'professionalPhoneNumber',
                response['professional_phone_number'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _instagram = ProfileFieldFilter.getVisibleValue(
                'instagram',
                response['instagram'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _linkedin = ProfileFieldFilter.getVisibleValue(
                'linkedin',
                response['linkedin'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _twitter = ProfileFieldFilter.getVisibleValue(
                'twitter',
                response['twitter'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _spotify = ProfileFieldFilter.getVisibleValue(
                'spotify',
                response['spotify'] ?? '',
                _sharedCardPermission,
                fieldAssignments);
            _bio = ProfileFieldFilter.getVisibleValue('bio',
                response['bio'] ?? '', _sharedCardPermission, fieldAssignments);
            _customLinks = response['custom_links'] != null
                ? List<dynamic>.from(response['custom_links'] is String
                    ? jsonDecode(response['custom_links'] as String)
                        as List<dynamic>
                    : response['custom_links'] as List<dynamic>)
                : [];

            if (response['experience'] != null) {
              final expData = response['experience'] is String
                  ? jsonDecode(response['experience'] as String)
                  : response['experience'];
              if (expData is List) {
                _experience = expData
                    .map((e) =>
                        ExperienceItem.fromJson(e as Map<String, dynamic>))
                    .toList();
                for (final exp in _experience) {
                  if (exp.isCurrent ||
                      exp.endDate.trim().toLowerCase() == 'present' ||
                      exp.endDate.toLowerCase().contains('present')) {
                    if (exp.company.trim().isNotEmpty) {
                      _company = exp.company.trim();
                      break;
                    }
                  }
                }
              }
            } else {
              _experience = [];
            }

            if (response['education'] != null) {
              final eduData = response['education'] is String
                  ? jsonDecode(response['education'] as String)
                  : response['education'];
              if (eduData is List) {
                _education = eduData
                    .map((e) =>
                        EducationItem.fromJson(e as Map<String, dynamic>))
                    .toList();
              }
            } else {
              _education = [];
            }

            if (response['skills'] != null) {
              final skillsData = response['skills'] is String
                  ? jsonDecode(response['skills'] as String)
                  : response['skills'];
              if (skillsData is List) {
                _skills =
                    List<String>.from(skillsData.map((e) => e.toString()));
              }
            } else {
              _skills = [];
            }
          });

          // Build per-card filtered field sets
          final Map<String, dynamic>? fa = fieldAssignments;

          String filterField(String field, String rawValue) {
            return ProfileFieldFilter.getVisibleValue(
                field, rawValue, 'casual', fa);
          }

          String filterFieldPro(String field, String rawValue) {
            return ProfileFieldFilter.getVisibleValue(
                field, rawValue, 'professional', fa);
          }

          setState(() {
            final String rawEmail = response['email'] ?? '';
            final String rawPhone = response['phone_number'] ?? '';
            final String rawProfEmail = response['professional_email'] ?? '';
            final String rawProfPhone =
                response['professional_phone_number'] ?? '';

            final String filterCasualEmail = filterField('email', rawEmail);
            final String filterCasualPhone =
                filterField('phoneNumber', rawPhone);

            final String filterProfEmail =
                filterFieldPro('professionalEmail', rawProfEmail);

            final String filterProfPhone =
                filterFieldPro('professionalPhoneNumber', rawProfPhone);

            _casualFields = {
              'email': filterCasualEmail,
              'phoneNumber': filterCasualPhone,
              'instagram':
                  filterField('instagram', response['instagram'] ?? ''),
              'linkedin': filterField('linkedin', response['linkedin'] ?? ''),
              'twitter': filterField('twitter', response['twitter'] ?? ''),
              'spotify': filterField('spotify', response['spotify'] ?? ''),
              'bio': filterField('bio', response['bio'] ?? ''),
            };

            final String rawProfBio = response['professional_bio'] ?? '';
            _professionalBio = ProfileFieldFilter.getVisibleValue(
                'professionalBio',
                rawProfBio,
                _sharedCardPermission,
                fieldAssignments);

            final String effectiveProfEmail = filterProfEmail.isNotEmpty
                ? filterProfEmail
                : filterFieldPro('email', rawEmail);

            final String effectiveProfPhone = filterProfPhone.isNotEmpty
                ? filterProfPhone
                : filterFieldPro('phoneNumber', rawPhone);

            _professionalFields = {
              'email': effectiveProfEmail,
              'phoneNumber': effectiveProfPhone,
              'instagram':
                  filterFieldPro('instagram', response['instagram'] ?? ''),
              'linkedin':
                  filterFieldPro('linkedin', response['linkedin'] ?? ''),
              'twitter': filterFieldPro('twitter', response['twitter'] ?? ''),
              'spotify': filterFieldPro('spotify', response['spotify'] ?? ''),
              'bio': filterFieldPro('professionalBio', rawProfBio),
            };
          });
        }
      } catch (e) {
        print("Error fetching connection profile data: $e");
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.04),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00F2FE), size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFA1A4B0),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded,
                color: Color(0xFF5E626E), size: 15),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final surfaceSecondaryColor = context.surfaceSecondary;
              Clipboard.setData(ClipboardData(text: value)).then((_) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text("Copied $label to clipboard!"),
                    backgroundColor: surfaceSecondaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCasualSocialCard(
      String platform, String name, String assetPath, String handle) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showSocialActionSheet(context, platform, name, handle, assetPath);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  assetPath,
                  width: 16,
                  height: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    handle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF00F2FE),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSocialUrl(String platform, String handle) {
    return SocialLauncher.getSocialUrl(platform, handle);
  }

  void _showSocialActionSheet(
    BuildContext context,
    String platform,
    String displayName,
    String handle,
    String assetPath,
  ) {
    final url = _getSocialUrl(platform, handle);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfacePrimary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: context.borderMuted,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.accentPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        assetPath,
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$handle',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.borderMuted,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        url,
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied link to clipboard!',
                                  style: TextStyle(color: context.textPrimary)),
                              backgroundColor: context.surfaceSecondary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.copy_rounded,
                          color: context.textSecondary, size: 18),
                      label: Text(
                        "Copy Link",
                        style: TextStyle(
                            color: context.textSecondary,
                            fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: context.borderMuted),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await SocialLauncher.launchSocialLink(
                              context, platform, handle);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.open_in_new_rounded,
                            color: Colors.black, size: 18),
                        label: const Text(
                          "Open Account",
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSocialGridSection(Map<String, String> fields) {
    final linkedin = fields['linkedin']?.trim() ?? '';
    final twitter = fields['twitter']?.trim() ?? '';
    final instagram = fields['instagram']?.trim() ?? '';
    final spotify = fields['spotify']?.trim() ?? '';

    final List<Map<String, String>> activeSocials = [];
    if (linkedin.isNotEmpty) {
      activeSocials.add({
        'platform': 'linkedin',
        'name': 'LinkedIn',
        'asset': 'assets/icons/linkedin.png',
        'handle': linkedin
      });
    }
    if (twitter.isNotEmpty) {
      activeSocials.add({
        'platform': 'twitter',
        'name': 'X (Twitter)',
        'asset': 'assets/icons/twitter.png',
        'handle': twitter
      });
    }
    if (instagram.isNotEmpty) {
      activeSocials.add({
        'platform': 'instagram',
        'name': 'Instagram',
        'asset': 'assets/icons/instagram.png',
        'handle': instagram
      });
    }
    if (spotify.isNotEmpty) {
      activeSocials.add({
        'platform': 'spotify',
        'name': 'Spotify',
        'asset': 'assets/icons/spotify.png',
        'handle': spotify
      });
    }

    if (activeSocials.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'SOCIAL PROFILES',
          style: context.captionText.copyWith(
            color: context.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        GridView.count(
          padding: EdgeInsets.only(top: 10),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: activeSocials.map((social) {
            return _buildCasualSocialCard(
              social['platform']!,
              social['name']!,
              social['asset']!,
              social['handle']!,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSkeletonHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1013),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Profile Space',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Digital Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFA1A4B0),
                    fontSize: 11.0,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 32,
            height: 32,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvasBackground,
      body: SafeArea(
        top: false,
        child: Skeletonizer(
          enabled: _isLoading,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.marginStandard,
                    right: AppDimensions.marginStandard,
                    top: 56.0,
                  ),
                  child: _buildSkeletonHeader(),
                ),
                const SizedBox(
                  height: 24,
                ),

                // Profile Details
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.marginStandard),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section: Identity (Photo, Name, Vibe)
                      Container(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 72,
                              height: 72,
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFEC4899),
                                    Color(0xFF00F2FE)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: ClipOval(
                                child: (_avatarUrl.isNotEmpty &&
                                        _avatarUrl.startsWith('http'))
                                    ? Image.network(
                                        _avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          color: const Color(0xFF1E1F32),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _name.isNotEmpty
                                                ? _name
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : "?",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFF1E1F32),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _name.isNotEmpty
                                              ? _name
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : "?",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Name and Vibe
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Inter',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final String subtitle =
                                          _company.trim().isNotEmpty
                                              ? _company.trim()
                                              : (_profession.trim().isNotEmpty
                                                  ? _profession.trim()
                                                  : (_handle.trim().isNotEmpty
                                                      ? '@${_handle.trim()}'
                                                      : 'Jana'));
                                      if (subtitle.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFA1A4B0),
                                            fontSize: 12,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Vouch Button / Edit Button Badge
                                      Consumer2<ProfileProvider, VouchProvider>(
                                        builder:
                                            (context, pProvider, vProvider, _) {
                                          final myId = pProvider.userId;
                                          if (myId != null &&
                                              _targetUserId != 0 &&
                                              myId == _targetUserId) {
                                            return InkWell(
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const YetToBeBuiltProfilePage(
                                                            isEditingMode:
                                                                true),
                                                  ),
                                                );
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 11,
                                                        vertical: 4.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.25),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.edit_rounded,
                                                        color:
                                                            Color(0xFF00F2FE),
                                                        size: 12),
                                                    SizedBox(width: 4.5),
                                                    Text(
                                                      "Edit Profile",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'Inter',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                          if (myId == null ||
                                              _targetUserId == 0) {
                                            return const SizedBox.shrink();
                                          }
                                          final hasVouched =
                                              vProvider.hasVouchedFor(
                                                  myId, _targetUserId);
                                          if (hasVouched) {
                                            final isPending =
                                                vProvider.getCachedVouchStatus(
                                                        myId, _targetUserId) ==
                                                    'pending';
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isPending
                                                    ? const Color(0xFFF59E0B)
                                                        .withValues(alpha: 0.12)
                                                    : Colors.white.withValues(
                                                        alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isPending
                                                      ? const Color(0xFFF59E0B)
                                                          .withValues(
                                                              alpha: 0.35)
                                                      : Colors.white.withValues(
                                                          alpha: 0.20),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isPending
                                                        ? Icons
                                                            .hourglass_top_rounded
                                                        : Icons
                                                            .verified_rounded,
                                                    color: isPending
                                                        ? const Color(
                                                            0xFFF59E0B)
                                                        : Colors.white70,
                                                    size: 11,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isPending
                                                        ? "Vouch Requested"
                                                        : "Vouched",
                                                    style: TextStyle(
                                                      color: isPending
                                                          ? const Color(
                                                              0xFFF59E0B)
                                                          : Colors.white70,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Inter',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          return InkWell(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              VouchBottomSheet.show(
                                                context: context,
                                                targetUserId: _targetUserId,
                                                targetUserName: _name,
                                                targetUserAvatar: _avatarUrl,
                                                targetUserProfession:
                                                    _profession,
                                                onVouched: () {
                                                  final myId =
                                                      profileProvider.userId;
                                                  if (myId != null &&
                                                      _targetUserId != 0) {
                                                    Provider.of<VouchProvider>(
                                                            context,
                                                            listen: false)
                                                        .getMutualIntents(
                                                      userId1: myId,
                                                      userId2: _targetUserId,
                                                    )
                                                        .then((intents) {
                                                      if (mounted) {
                                                        setState(() =>
                                                            _mutualIntents =
                                                                intents);
                                                      }
                                                    });
                                                  }
                                                  setState(() {});
                                                },
                                              );
                                            },
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.25),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.shield_rounded,
                                                      color: Colors.white,
                                                      size: 11),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "Vouch",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Inter',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_mutualIntents.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_open_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "MUTUAL INTENT MATCH",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "You and $_name mutually signaled: ${_mutualIntents.join(' • ')}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // VOUCHES SECTION
                      if (_targetUserId != 0) ...[
                        VouchesListWidget(
                          userId: _targetUserId,
                          userName: _name,
                          isOwnProfile: (profileProvider.userId != null &&
                              profileProvider.userId == _targetUserId),
                        ),
                      ],

                      // Section: My Story (Bio)
                      if ((_previewFields['bio'] ?? '').trim().isNotEmpty) ...[
                        Text(
                          'MY STORY',
                          style: context.captionText.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(1, 8, 8, 8),
                          child: Text(
                            _previewFields['bio']!,
                            style: context.bodyText.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // DETAILS DISPLAY HEADER
                      Text(
                        'CONNECTION DETAILS',
                        style: context.captionText.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_profession.isNotEmpty)
                        _buildReadOnlyField(
                          label: 'Profession',
                          value: _profession,
                          icon: Icons.work_outline_rounded,
                        ),

                      if (_company.isNotEmpty)
                        _buildReadOnlyField(
                          label: 'Company',
                          value: _company,
                          icon: Icons.business_outlined,
                        ),

                      if ((_previewFields['email'] ?? '').isNotEmpty)
                        _buildReadOnlyField(
                          label: 'Email Address',
                          value: _previewFields['email'] ?? '',
                          icon: Icons.email_outlined,
                        ),

                      if ((_previewFields['phoneNumber'] ?? '').isNotEmpty)
                        _buildReadOnlyField(
                          label: 'Phone Number',
                          value: _previewFields['phoneNumber'] ?? '',
                          icon: Icons.phone_android_outlined,
                        ),

                      // SOCIAL SECTIONS
                      _buildSocialGridSection(_previewFields),

                      // CUSTOM LINKS
                      ..._buildCustomLinksList(_fieldAssignments),

                      if (_experience.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        ExperienceTimelineSection(
                          experience: _experience,
                          isOwner: false,
                        ),
                      ],
                      if (_education.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        EducationSection(
                          education: _education,
                          isOwner: false,
                        ),
                      ],
                      if (_skills.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        SkillsSection(
                          skills: _skills,
                          isOwner: false,
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginStandard,
            vertical: 12.0,
          ),
          decoration: BoxDecoration(
            color: context.canvasBackground,
            border: Border(
              top: BorderSide(
                color: context.surfaceSecondary,
                width: 1.0,
              ),
            ),
          ),
          child: Builder(
            builder: (context) {
              final connProvider = Provider.of<ConnectionProvider>(context);
              final notifProvider = Provider.of<NotificationProvider>(context);
              final myUserId = profileProvider.userId;
              final targetId = _targetUserId;
              final isConnected = connProvider.isConnected(targetId);
              final isOwnProfile = myUserId != null && myUserId == targetId;

              if (isOwnProfile) {
                return const SizedBox.shrink();
              }

              if (!isConnected) {
                final hasSent = notifProvider.hasSentDirectRequest(targetId);
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasSent
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                DirectConnectionSheet.show(
                                  context: context,
                                  targetUserId: targetId,
                                  targetUserName: _name,
                                  targetUserAvatar: _avatarUrl,
                                  targetUserProfession: _profession,
                                );
                              },
                        icon: Icon(
                          hasSent
                              ? Icons.check_circle_outline
                              : Icons.person_add_rounded,
                          color: hasSent ? context.textSecondary : Colors.black,
                          size: 20,
                        ),
                        label: Text(
                          hasSent ? "Request Sent" : "Send Connection Request",
                          style: context.bodyText.copyWith(
                            color:
                                hasSent ? context.textSecondary : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasSent
                              ? context.surfaceSecondary
                              : context.accentPrimary,
                          foregroundColor:
                              hasSent ? context.textSecondary : Colors.black,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: GlassmorphicButton(
                      onPressed: () {
                        _showDeleteConfirmation(
                            context, widget.profileData, connectionProvider);
                      },
                      borderRadius: BorderRadius.circular(99),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        "Remove Connection",
                        style: context.bodyText.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IndividualChatPage(
                              connectionData: widget.profileData,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentPrimary,
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        elevation: 0,
                      ),
                      child: Text(
                        "Message",
                        style: context.bodyText.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds the detail + social widgets when the shared card permission is
  /// 'both'. Deduplicates identical values across casual/professional and
  /// only renders fields that actually have data.

  List<Widget> _buildCustomLinksList(dynamic fieldAssignments) {
    final widgets = <Widget>[];

    // Filter links based on visibility (visible unless explicitly private)
    final visibleLinks = _customLinks.where((link) {
      final String linkId = link['id'] ?? '';
      return ProfileFieldFilter.isFieldVisible(
          linkId, 'both', fieldAssignments);
    }).toList();

    if (visibleLinks.isEmpty) return widgets;

    widgets.add(const SizedBox(height: 24));
    widgets.add(Text(
      'CUSTOM LINKS',
      style: context.captionText.copyWith(
        color: context.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ));
    widgets.add(const SizedBox(height: 16));

    for (final link in visibleLinks) {
      final String name = link['name'] ?? '';
      final String url = link['url'] ?? '';

      widgets.add(_buildReadOnlyField(
        label: name,
        value: url,
        icon: Icons.link_rounded,
      ));
    }

    return widgets;
  }

  Future<void> _deleteProfileLocally(
      String id, ConnectionProvider provider) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      final myUserId =
          Provider.of<ProfileProvider>(context, listen: false).userId;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final vouchProvider = Provider.of<VouchProvider>(context, listen: false);
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);

      await provider.deleteProfile(intId,
          onRoomCleanup: (profileId, roomId) async {
        await chatProvider.handleRoomCleanup(profileId, roomId);
      }, onVouchCleanup: () async {
        if (myUserId != null && intId != 0) {
          try {
            await vouchProvider.deleteVouchesBetween(
                userId1: myUserId, userId2: intId);
          } catch (e) {
            debugPrint("Error deleting vouches in cleanup: $e");
          }
          try {
            feedProvider.fetchInitialFeed(silent: true);
          } catch (_) {}
        }
      });
    } catch (e) {
      print("Error deleting profile locally: $e");
    }
  }

  Future<void> _blockProfileLocally(
      String id, ConnectionProvider provider) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      await provider.blockUser(intId);
    } catch (e) {
      print("Error blocking profile locally: $e");
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) async {
    final name = connection['name'] ?? 'this contact';
    final profileIdStr =
        (connection['id'] ?? connection['connection_profile_id'] ?? '')
            .toString();
    final isBlockedByMe = connection['isBlockedByMe'] == true;

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusPremiumCard),
            side: BorderSide(color: context.surfaceSecondary, width: 1.5),
          ),
          title: Text(
            "Manage Connection",
            style: context.screenHeading.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isBlockedByMe
                ? "What action would you like to perform for $name? You can unblock them or disconnect entirely."
                : "What action would you like to perform for $name? Blocking will prevent them from contacting you, while deleting simply disconnects you.",
            style: context.bodyText.copyWith(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              child: Text("Cancel",
                  style: TextStyle(color: context.textSecondary)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text("Report User",
                  style: TextStyle(
                      color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _showReportUserDialog(context, connection, provider);
              },
            ),
            isBlockedByMe
                ? TextButton(
                    child: const Text("Unblock User",
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        final intId = int.tryParse(profileIdStr) ?? 0;
                        await provider.unblockUser(intId);
                        if (!mounted) return;
                        navigator.pop(); // Pop detail page
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("User unblocked successfully"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Could not unblock user. Please try again.")),
                        );
                      }
                    },
                  )
                : TextButton(
                    child: const Text("Block User",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        await _blockProfileLocally(profileIdStr, provider);
                        if (!mounted) return;
                        navigator.pop(); // Pop profile detail screen
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("User blocked"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Could not block user. Please try again.")),
                        );
                      }
                    },
                  ),
            TextButton(
              child: const Text("Delete Connection",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.normal)),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);
                if (mounted) {
                  Navigator.pop(context);
                }
                messenger.showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: context.surfaceSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: context.borderMuted.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Connection and chat history deleted",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                _deleteProfileLocally(profileIdStr, provider);
              },
            ),
          ],
        );
      },
    );
  }

  void _showReportUserDialog(BuildContext context,
      Map<String, dynamic> connection, ConnectionProvider provider) {
    final name = connection['name'] ?? 'this contact';
    final profileIdStr =
        (connection['id'] ?? connection['connection_profile_id'] ?? '')
            .toString();
    final intId = int.tryParse(profileIdStr) ?? 0;

    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return GlassmorphicAlertDialog(
              title: Text(
                "Report & Disconnect $name",
                style:
                    context.screenHeading.copyWith(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Please select the reason for reporting this user:",
                        style: context.bodyText
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ...[
                        'Spam',
                        'Harassment or Abuse',
                        'Inappropriate Behavior',
                        'Other'
                      ].map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: isSubmitting
                              ? null
                              : () {
                                  setStateBuilder(() {
                                    selectedReason = reason;
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? context.accentPrimary
                                      : context.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  reason,
                                  style: context.bodyText.copyWith(
                                    color: isSelected
                                        ? context.textPrimary
                                        : context.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        "Additional Details (Optional):",
                        style: context.bodyText
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailsController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          hintText: "Enter details here...",
                          hintStyle:
                              TextStyle(color: context.textMuted, fontSize: 13),
                          fillColor: context.surfaceSecondary,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: context.borderMuted),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: context.accentPrimary),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: context.bodyText,
                      ),
                    ],
                  ),
                ),
              ),
              actions: isSubmitting
                  ? [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text("Cancel",
                            style: TextStyle(color: context.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () async {
                          setStateBuilder(() {
                            isSubmitting = true;
                          });

                          try {
                            // 1. Report User
                            await Provider.of<ChatProvider>(context,
                                    listen: false)
                                .reportMessage(
                              reportedUserId: intId,
                              reason: selectedReason,
                              additionalDetails:
                                  detailsController.text.trim().isEmpty
                                      ? null
                                      : detailsController.text.trim(),
                            );

                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.of(dialogContext).pop();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: context.surfaceSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: context.borderMuted
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: Colors.greenAccent, size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Connection deleted and contact reported.",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            _deleteProfileLocally(profileIdStr, provider);
                          } catch (e) {
                            if (mounted) {
                              setStateBuilder(() {
                                isSubmitting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Could not file report. Please check your network and try again."),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Submit & Delete",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}
