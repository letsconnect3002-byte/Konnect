import 'dart:convert';
import 'dart:math';

import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Models/custom_link.dart';
import 'package:connect/Repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

sealed class ProfileState {}
class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final int userId;
  final bool isCreated;
  ProfileLoaded(this.userId, this.isCreated);
}
class ProfileError extends ProfileState {
  final AppError error;
  ProfileError(this.error);
}

class ProfileProvider with ChangeNotifier {
  final ProfileRepository _repository;
  bool _blurBackground = true;
  bool get blurBackground => _blurBackground;

  ProfileProvider({ProfileRepository? profileRepository})
      : _repository = profileRepository ?? SupabaseProfileRepository();

  Future<void> setBlurBackground(bool val) async {
    _blurBackground = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blur_background', val);
  }

  Future<void> loadBackgroundBlurPref() async {
    final prefs = await SharedPreferences.getInstance();
    _blurBackground = prefs.getBool('blur_background') ?? true;
    notifyListeners();
  }

  String _defaultCardVisibility = 'casual'; // 'casual', 'professional', or 'both'
  String get defaultCardVisibility => _defaultCardVisibility;

  Future<void> setDefaultCardVisibility(String val) async {
    final String cleanVal = val == 'both' ? 'casual' : val;
    _defaultCardVisibility = cleanVal;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_card_visibility', cleanVal);

    final myUserId = userId;
    if (myUserId != null) {
      try {
        await _repository.updateProfileField(myUserId, 'default_card_visibility', cleanVal);
        print("Successfully synced default_card_visibility to Supabase: $cleanVal");
      } catch (e) {
        print("Error syncing default_card_visibility to Supabase: $e");
      }
    }
  }

  Future<void> loadDefaultCardVisibilityPref() async {
    final prefs = await SharedPreferences.getInstance();
    String val = prefs.getString('default_card_visibility') ?? 'casual';
    if (val == 'both') {
      val = 'casual';
      await prefs.setString('default_card_visibility', 'casual');
    }
    _defaultCardVisibility = val;
    notifyListeners();
  }

  // Profile fields
  String name = '';
  String profession = '';
  String email = '';
  String professionalEmail = '';
  String phoneNumber = '';
  String professionalPhoneNumber = '';
  String instagram = '';
  String linkedin = '';
  String twitter = '';
  String company = '';
  String bio = '';
  String professionalBio = '';
  String avatarUrl = '';
  String gender = '';
  String spotify = '';
  List<CustomLink> customLinks = [];
  bool showProfileToConnections = true;

  // Quick Identity fields
  String vibeTag = '';
  List<String> interestTags = [];
  bool quickSetupComplete = false;
  bool showSignUpNext = false;

  String? _ownerId;
  int? _lastKnownUserId;
  bool _lastKnownIsCreated = false;

  ProfileState _state = ProfileInitial();
  ProfileState get state => _state;

  int? get userId => _state is ProfileLoaded ? (_state as ProfileLoaded).userId : null;
  bool get isCreated => _state is ProfileLoaded ? (_state as ProfileLoaded).isCreated : false;
  bool get hasData => userId != null && name.isNotEmpty;

  List<String> get missingEssentialFields {
    final List<String> missing = [];

    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.toLowerCase() == 'jane doe') {
      missing.add('Name');
    }

    if (avatarUrl.trim().isEmpty) {
      missing.add('Profile Photo');
    }

    if (profession.trim().isEmpty && company.trim().isEmpty) {
      missing.add('Headline');
    }

    final hasContact = email.trim().isNotEmpty ||
        professionalEmail.trim().isNotEmpty ||
        phoneNumber.trim().isNotEmpty ||
        professionalPhoneNumber.trim().isNotEmpty;
    if (!hasContact) {
      missing.add('Contact Info');
    }

    return missing;
  }

  int get profileCompletionPct => ((4 - missingEssentialFields.length) * 25);

  bool get isEssentialProfileComplete => missingEssentialFields.isEmpty;

  DateTime? _profileNudgeDismissedAt;
  DateTime? get profileNudgeDismissedAt => _profileNudgeDismissedAt;

  bool get shouldShowProfileNudge {
    if (isEssentialProfileComplete || !hasData) return false;
    if (_profileNudgeDismissedAt != null) {
      final diff = DateTime.now().toUtc().difference(_profileNudgeDismissedAt!);
      if (diff.inHours < 48) return false;
    }
    return true;
  }

  void resetNudgeDismissalLocal() {
    _profileNudgeDismissedAt = null;
    notifyListeners();
  }

  Future<void> dismissProfileNudge() async {
    final now = DateTime.now().toUtc();
    _profileNudgeDismissedAt = now;
    notifyListeners();
    final myUserId = userId;
    if (myUserId != null) {
      try {
        await _repository.updateProfileField(myUserId, 'profile_nudge_dismissed_at', now.toIso8601String());
        print("Successfully synced profile_nudge_dismissed_at to Supabase: ${now.toIso8601String()}");
      } catch (e) {
        print("Error syncing profile_nudge_dismissed_at to Supabase: $e");
      }
    }
  }

  AppError? get lastError => _state is ProfileError ? (_state as ProfileError).error : null;

  void _setError(Object e) {
    _state = ProfileError(AppError.from(e));
    notifyListeners();
  }

  void _setLoadedState(int userIdVal, bool isCreatedVal) {
    _lastKnownUserId = userIdVal;
    _lastKnownIsCreated = isCreatedVal;
    _state = ProfileLoaded(userIdVal, isCreatedVal);
    LocalDatabaseHelper.activeUserId = userIdVal;
  }

  void clearError() {
    if (_lastKnownUserId != null) {
      _state = ProfileLoaded(_lastKnownUserId!, _lastKnownIsCreated);
    } else {
      _state = ProfileInitial();
    }
    notifyListeners();
  }

  void _clearDataFields() {
    name = '';
    profession = '';
    email = '';
    professionalEmail = '';
    phoneNumber = '';
    professionalPhoneNumber = '';
    instagram = '';
    linkedin = '';
    twitter = '';
    spotify = '';
    company = '';
    bio = '';
    professionalBio = '';
    avatarUrl = '';
    gender = '';
    customLinks = [];
    vibeTag = '';
    interestTags = [];
    quickSetupComplete = false;
  }

  // Which card(s) each field appears on (Casual / Professional).
  Map<String, FieldCardAssignment> fieldAssignments = {};

  void _ensureDefaultFieldAssignments() {
    for (final field in assignableProfileFields) {
      fieldAssignments.putIfAbsent(
        field,
        () {
          if (field == 'name' || field == 'avatarUrl') {
            return FieldCardAssignment(casual: true, professional: true);
          }
          return FieldCardAssignment(casual: false, professional: true);
        },
      );
    }
  }

  bool isFieldOnCard(String field, ProfileCardType card) {
    _ensureDefaultFieldAssignments();
    if (field == 'vibeTag' || field == 'interestTags') {
      return card == ProfileCardType.casual;
    }
    final assignment = fieldAssignments[field];
    if (assignment == null) {
      if (card == ProfileCardType.casual) {
        return field == 'name' || field == 'avatarUrl';
      } else {
        return true;
      }
    }
    return card == ProfileCardType.casual
        ? assignment.casual
        : assignment.professional;
  }

  Future<void> toggleFieldOnCard(String field, ProfileCardType card) async {
    _ensureDefaultFieldAssignments();
    fieldAssignments.putIfAbsent(
        field, () => FieldCardAssignment(casual: false, professional: true));
    final current = fieldAssignments[field]!;
    if (card == ProfileCardType.casual) {
      fieldAssignments[field] = current.copyWith(casual: !current.casual);
    } else {
      fieldAssignments[field] =
          current.copyWith(professional: !current.professional);
    }
    notifyListeners();
    final currentUserId = userId;
    if (currentUserId != null) {
      try {
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
        await _repository.updateProfileField(currentUserId, 'field_assignments', assignmentsMap);
        print("Updated field assignments in Supabase");
      } catch (e) {
        print("Error saving field assignments to Supabase: $e");
        _setError(e);
      }
    }
  }

  Future<void> setFieldOnCard(
      String field, ProfileCardType card, bool enabled) async {
    _ensureDefaultFieldAssignments();
    fieldAssignments.putIfAbsent(
        field, () => FieldCardAssignment(casual: false, professional: true));
    final current = fieldAssignments[field]!;
    if (card == ProfileCardType.casual) {
      fieldAssignments[field] = current.copyWith(casual: enabled);
    } else {
      fieldAssignments[field] = current.copyWith(professional: enabled);
    }
    notifyListeners();
    final currentUserId = userId;
    if (currentUserId != null) {
      try {
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
        await _repository.updateProfileField(currentUserId, 'field_assignments', assignmentsMap);
        print("Updated field assignments in Supabase");
      } catch (e) {
        print("Error saving field assignments to Supabase: $e");
        _setError(e);
      }
    }
  }

  bool isFieldPrivate(String field) {
    _ensureDefaultFieldAssignments();
    final assignment = fieldAssignments[field];
    return assignment?.isPrivate ?? false;
  }

  Future<void> setFieldPrivate(String field, bool private) async {
    _ensureDefaultFieldAssignments();
    fieldAssignments.putIfAbsent(
        field, () => FieldCardAssignment(casual: false, professional: true));
    final current = fieldAssignments[field]!;
    fieldAssignments[field] = current.copyWith(isPrivate: private);
    notifyListeners();
    final currentUserId = userId;
    if (currentUserId != null) {
      try {
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
        await _repository.updateProfileField(currentUserId, 'field_assignments', assignmentsMap);
        print("Updated field assignments privacy in Supabase");
      } catch (e) {
        print("Error saving field assignments privacy to Supabase: $e");
        _setError(e);
      }
    }
  }

  String? getFieldValue(String field) {
    switch (field) {
      case 'name':
        return name;
      case 'profession':
        return profession;
      case 'company':
        return company;
      case 'email':
        return email;
      case 'professionalEmail':
        return professionalEmail;
      case 'phoneNumber':
        return phoneNumber;
      case 'professionalPhoneNumber':
        return professionalPhoneNumber;
      case 'bio':
        return bio;
      case 'professionalBio':
        return professionalBio;
      case 'avatarUrl':
        return avatarUrl;
      case 'linkedin':
        return linkedin;
      case 'twitter':
        return twitter;
      case 'instagram':
        return instagram;
      case 'spotify':
        return spotify;
      default:
        return null;
    }
  }

  // Helper to get or create a unique owner_id for this device
  Future<String> _getOrCreateOwnerId() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _ownerId = session.user.id;
      return _ownerId!;
    }
    if (_ownerId != null) return _ownerId!;
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('owner_id');
    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('owner_id', storedId);
    }
    _ownerId = storedId;
    return _ownerId!;
  }

  Future<void> ensureProfileExists() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final ownerId = session.user.id;
    try {
      _state = ProfileLoading();
      notifyListeners();

      final list = await _repository.checkMyProfileExists(ownerId);
      if (list.isEmpty) {
        clearFields();
        name = session.user.email?.split('@')[0] ?? 'User';
        email = session.user.email ?? '';
        profession = 'Professional';
        gender = session.user.userMetadata?['gender'] as String? ?? '';
        
        _setLoadedState(0, false);
        await saveProfileData(isMyProfile: true);
        print("Default profile created for owner ID: $ownerId");
      } else {
        final existingId = list.first['id'] as int;
        _setLoadedState(existingId, true);
        notifyListeners();
      }
    } catch (e) {
      print("Error in ensureProfileExists: $e");
      _setError(e);
    }
  }

  void setValue(String field, String value) {
    switch (field) {
      case 'name':
        name = value;
        break;
      case 'profession':
        profession = value;
        break;
      case 'email':
        email = value;
        break;
      case 'professionalEmail':
        professionalEmail = value;
        break;
      case 'phoneNumber':
        phoneNumber = value;
        break;
      case 'professionalPhoneNumber':
        professionalPhoneNumber = value;
        break;
      case 'instagram':
        instagram = value;
        break;
      case 'linkedin':
        linkedin = value;
        break;
      case 'twitter':
        twitter = value;
        break;
      case 'company':
        company = value;
        break;
      case 'bio':
        bio = value;
        break;
      case 'professionalBio':
        professionalBio = value;
        break;
      case 'avatarUrl':
        avatarUrl = value;
        break;
      case 'gender':
        gender = value;
        break;
      case 'spotify':
        spotify = value;
        break;
      case 'vibeTag':
      case 'vibe_tag':
        vibeTag = value;
        break;
      case 'interestTags':
      case 'interest_tags':
        interestTags = value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        break;
    }
    notifyListeners();
  }

  // Update a specific field in the profile
  Future<void> updateProfileField(String field, String value, int id) async {
    setValue(field, value);

    String dbField = field;
    if (field == 'phoneNumber') {
      dbField = 'phone_number';
    } else if (field == 'professionalEmail') {
      dbField = 'professional_email';
    } else if (field == 'professionalPhoneNumber') {
      dbField = 'professional_phone_number';
    } else if (field == 'professionalBio') {
      dbField = 'professional_bio';
    } else if (field == 'avatarUrl') {
      dbField = 'avatar_url';
    } else if (field == 'vibeTag' || field == 'vibe_tag') {
      dbField = 'vibe_tag';
    } else if (field == 'interestTags' || field == 'interest_tags') {
      dbField = 'interest_tags';
    }

    try {
      dynamic dbValue = value;
      if (dbField == 'interest_tags') {
        dbValue = value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      }
      await _repository.updateProfileField(id, dbField, dbValue);
      print("Updated field $field in database to $dbValue");
    } catch (e) {
      print("Error updating profile field: $e");
      _setError(e);
    }

    notifyListeners();
  }

  Future<void> addCustomLink(String name, String url, int? profileId) async {
    final newLink = CustomLink(
      id: 'custom_link_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      url: url,
    );
    customLinks.add(newLink);
    fieldAssignments[newLink.id] = FieldCardAssignment(casual: false, professional: true);
    notifyListeners();
    if (profileId != null) {
      await saveOrUpdateProfile();
    }
  }

  Future<void> editCustomLink(String id, String name, String url, int? profileId) async {
    final idx = customLinks.indexWhere((l) => l.id == id);
    if (idx != -1) {
      customLinks[idx] = customLinks[idx].copyWith(name: name, url: url);
      notifyListeners();
      if (profileId != null) {
        await saveOrUpdateProfile();
      }
    }
  }

  Future<void> removeCustomLink(String id, int? profileId) async {
    customLinks.removeWhere((l) => l.id == id);
    fieldAssignments.remove(id);
    notifyListeners();
    if (profileId != null) {
      await saveOrUpdateProfile();
    }
  }

  Future<void> setShowProfileToConnections(bool value) async {
    showProfileToConnections = value;
    notifyListeners();
    final currentUserId = userId;
    if (currentUserId != null) {
      try {
        await _repository.updateProfileField(currentUserId, 'show_profile_to_connections', value);
        print("Updated show_profile_to_connections in Supabase to $value");
      } catch (e) {
        print("Error updating show_profile_to_connections in Supabase: $e");
        _setError(e);
      }
    }
  }



  // Method to fetch and set userId by profile type (isMyProfile)
  Future<void> fetchAndSetUserId(bool isMyProfile) async {
    final res = await fetchAndSetUserId2(isMyProfile);
    print("userId set to: $res");
  }

  Future<int?> fetchAndSetUserId2(bool isMyProfile) async {
    try {
      _clearDataFields();
      _state = ProfileLoading();
      notifyListeners();

      final ownerId = await _getOrCreateOwnerId();
      final list = await _repository.fetchProfileIdsByOwner(ownerId, isMyProfile);

      if (list.isNotEmpty) {
        final int id = list.first['id'] as int;
        _setLoadedState(id, true);
        notifyListeners();
        return id;
      }
    } catch (e) {
      print("Error fetching user ID: $e");
      _setError(e);
    }
    _state = ProfileInitial();
    notifyListeners();
    return null;
  }

  // Method to fetch and set userId by email
  Future<void> fetchAndSetUserIdEmail(String email) async {
    try {
      _state = ProfileLoading();
      notifyListeners();

      final list = await _repository.fetchProfileIdsByEmail(email);
      if (list.isNotEmpty) {
        final int id = list.first['id'] as int;
        _setLoadedState(id, true);
        notifyListeners();
      } else {
        _state = ProfileInitial();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching user ID by email: $e");
      _setError(e);
    }
  }

  // Load profile data from the database
  Future<Map<String, dynamic>> loadProfile(int id) async {
    final Map<String, dynamic> profileData = {
      "id": id,
      "name": "",
      "profession": "",
      "email": "",
      "professionalEmail": "",
      "phoneNumber": "",
      "professionalPhoneNumber": "",
      "instagram": "",
      "linkedin": "",
      "twitter": "",
      "spotify": "",
      "bio": "",
      "professionalBio": "",
      "avatarUrl": "",
      "gender": "",
      "custom_links": [],
      "showProfileToConnections": true,
    };
    try {
      // Only transition to ProfileLoading if we don't already have data.
      // This prevents userId from briefly becoming null during a background
      // refresh, which was causing buttons to flicker their enabled/disabled state.
      if (_state is! ProfileLoaded) {
        _state = ProfileLoading();
        notifyListeners();
      }

      final response = await _repository.loadProfile(id);

      if (response != null) {
        name = response['name'] ?? '';
        profession = response['profession'] ?? '';
        email = response['email'] ?? '';
        professionalEmail = response['professional_email'] ?? '';
        phoneNumber = response['phone_number'] ?? '';
        professionalPhoneNumber = response['professional_phone_number'] ?? '';
        instagram = response['instagram'] ?? '';
        linkedin = response['linkedin'] ?? '';
        twitter = response['twitter'] ?? '';
        spotify = response['spotify'] ?? '';
        company = response['company'] ?? '';
        bio = response['bio'] ?? '';
        professionalBio = response['professional_bio'] ?? '';
        avatarUrl = response['avatar_url'] ?? '';
        gender = response['gender'] ?? '';
        showProfileToConnections =
            response['show_profile_to_connections'] == true;

        if (response['profile_nudge_dismissed_at'] != null) {
          _profileNudgeDismissedAt =
              DateTime.tryParse(response['profile_nudge_dismissed_at'].toString())
                  ?.toUtc();
        } else {
          _profileNudgeDismissedAt = null;
        }


        vibeTag = response['vibe_tag'] ?? '';
        final List<dynamic>? interestsRaw = response['interest_tags'];
        if (interestsRaw != null) {
          interestTags = interestsRaw.map((e) => e.toString()).toList();
        } else {
          interestTags = [];
        }
        quickSetupComplete = response['quick_setup_complete'] == true;

        final dbVisibility = response['default_card_visibility']?.toString();
        if (dbVisibility != null && dbVisibility.isNotEmpty) {
          final String cleanVisibility = dbVisibility == 'both' ? 'casual' : dbVisibility;
          _defaultCardVisibility = cleanVisibility;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('default_card_visibility', cleanVisibility);
        }

        customLinks = [];
        if (response['custom_links'] != null) {
          try {
            final List<dynamic> decoded = response['custom_links'] is String
                ? jsonDecode(response['custom_links'] as String) as List<dynamic>
                : response['custom_links'] as List<dynamic>;
            customLinks = decoded.map((item) => CustomLink.fromJson(item as Map<String, dynamic>)).toList();
          } catch (e) {
            print("Error parsing custom_links: $e");
          }
        }

        profileData["name"] = name;
        profileData["profession"] = profession;
        profileData["email"] = email;
        profileData["professionalEmail"] = professionalEmail;
        profileData["phoneNumber"] = phoneNumber;
        profileData["professionalPhoneNumber"] = professionalPhoneNumber;
        profileData["instagram"] = instagram;
        profileData["linkedin"] = linkedin;
        profileData["twitter"] = twitter;
        profileData["spotify"] = spotify;
        profileData["company"] = company;
        profileData["bio"] = bio;
        profileData["professionalBio"] = professionalBio;
        profileData["avatarUrl"] = avatarUrl;
        profileData["gender"] = gender;
        profileData["custom_links"] = customLinks.map((l) => l.toJson()).toList();
        profileData["showProfileToConnections"] = showProfileToConnections;
        profileData["vibeTag"] = vibeTag;
        profileData["vibeTag"] = vibeTag;
        profileData["interestTags"] = interestTags;
        profileData["quickSetupComplete"] = quickSetupComplete;

        _setLoadedState(id, true);

        // Load field assignments from database if present
        if (response['field_assignments'] != null) {
          try {
            final Map<String, dynamic> decoded =
                response['field_assignments'] is String
                    ? jsonDecode(response['field_assignments'] as String)
                        as Map<String, dynamic>
                    : response['field_assignments'] as Map<String, dynamic>;
            _ensureDefaultFieldAssignments();
            for (final entry in decoded.entries) {
              if (entry.value is Map<String, dynamic>) {
                fieldAssignments[entry.key] = FieldCardAssignment.fromJson(
                    entry.value as Map<String, dynamic>);
              }
            }
          } catch (e) {
            print("Error parsing field_assignments: $e");
          }
        } else {
          _ensureDefaultFieldAssignments();
        }

        notifyListeners();
        return profileData;
      }
    } catch (e) {
      print("Error loading profile: $e");
      _setError(e);
    }
    return profileData;
  }

  // Save profile data to the database
  Future<void> saveProfileData({bool isMyProfile = true}) async {
    if (!isCreated) {
      try {
        final ownerId = await _getOrCreateOwnerId();
        _ensureDefaultFieldAssignments();
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));

        final insertedId = await _repository.insertProfile({
          'owner_id': ownerId,
          'name': name,
          'profession': profession,
          'email': email,
          'professional_email': professionalEmail,
          'phone_number': phoneNumber,
          'professional_phone_number': professionalPhoneNumber,
          'instagram': instagram,
          'linkedin': linkedin,
          'twitter': twitter,
          'spotify': spotify,
          'is_my_profile': isMyProfile,
          'company': company,
          'bio': bio,
          'professional_bio': professionalBio,
          'avatar_url': avatarUrl,
          'gender': gender,
          'show_profile_to_connections': showProfileToConnections,
          'field_assignments': assignmentsMap,
          'custom_links': customLinks.map((l) => l.toJson()).toList(),
          'vibe_tag': vibeTag,
          'interest_tags': interestTags,
          'quick_setup_complete': quickSetupComplete,
        });

        _setLoadedState(insertedId, true);
        notifyListeners();
        print("inserted");
      } catch (e) {
        print("Error saving profile data: $e");
        _setError(e);
      }
    }
  }

  Future<void> saveOrUpdateProfile() async {
    final ownerId = await _getOrCreateOwnerId();
    _ensureDefaultFieldAssignments();
    final assignmentsMap =
        fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));

    final data = {
      'name': name,
      'profession': profession,
      'email': email,
      'professional_email': professionalEmail,
      'phone_number': phoneNumber,
      'professional_phone_number': professionalPhoneNumber,
      'instagram': instagram,
      'linkedin': linkedin,
      'twitter': twitter,
      'spotify': spotify,
      'company': company,
      'bio': bio,
      'professional_bio': professionalBio,
      'avatar_url': avatarUrl,
      'show_profile_to_connections': showProfileToConnections,
      'field_assignments': assignmentsMap,
      'custom_links': customLinks.map((l) => l.toJson()).toList(),
      'vibe_tag': vibeTag,
      'interest_tags': interestTags,
      'quick_setup_complete': quickSetupComplete,
      'default_card_visibility': defaultCardVisibility == 'both' ? 'casual' : defaultCardVisibility,
    };

    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _repository.updateProfile(currentUserId, data);
        print("Profile updated successfully in Supabase");
      } else {
        final insertedId = await _repository.insertProfile({
          ...data,
          'owner_id': ownerId,
          'is_my_profile': true,
        });
        _setLoadedState(insertedId, true);
        print("Profile created successfully in Supabase with id: $insertedId");
      }
    } catch (e) {
      print("Error saving/updating profile in Supabase: $e");
      _setError(e);
    }
    notifyListeners();
  }

  // Clear profile fields after deletion
  void clearFields() {
    name = '';
    profession = '';
    email = '';
    professionalEmail = '';
    phoneNumber = '';
    professionalPhoneNumber = '';
    instagram = '';
    linkedin = '';
    twitter = '';
    spotify = '';
    customLinks = [];
    company = '';
    bio = '';
    professionalBio = '';
    avatarUrl = '';
    gender = '';
    showProfileToConnections = true;
    vibeTag = '';
    vibeTag = '';
    interestTags = [];
    quickSetupComplete = false;
    _state = ProfileInitial();
    LocalDatabaseHelper.activeUserId = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchProfileDataOnly(int id) async {
    try {
      final response = await _repository.fetchProfileDataOnly(id);

      if (response != null) {
        return {
          'id': response['id'],
          'name': response['name'] ?? '',
          'profession': response['profession'] ?? '',
          'email': response['email'] ?? '',
          'phoneNumber': response['phone_number'] ?? '',
          'instagram': response['instagram'] ?? '',
          'linkedin': response['linkedin'] ?? '',
          'twitter': response['twitter'] ?? '',
          'spotify': response['spotify'] ?? '',
          'isMyProfile': response['is_my_profile'] == true,
          'created_at': response['created_at'],
          'company': response['company'] ?? '',
          'avatarUrl': response['avatar_url'] ?? '',
          'bio': response['bio'] ?? '',
          'professionalBio': response['professional_bio'] ?? '',
          'showProfileToConnections':
              response['show_profile_to_connections'] == true,
          'cardTypes': response['card_types'] != null
              ? List<String>.from(response['card_types'] as List)
              : <String>[],
          'connection_profile_id': response['id'],
          'field_assignments': response['field_assignments'],
          'custom_links': response['custom_links'] != null
              ? (response['custom_links'] is String
                  ? jsonDecode(response['custom_links'] as String) as List<dynamic>
                  : response['custom_links'] as List<dynamic>)
              : <dynamic>[],
        };
      }
    } catch (e) {
      print("Error fetching profile data only: $e");
      _setError(e);
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchConnectionDetails(int idToFetch) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      return {
        'profile': null,
        'sharedCardPermission': 'casual',
        'mySharedCardToThem': 'casual',
      };
    }
    try {
      return await _repository.fetchConnectionDetails(currentUserId, idToFetch);
    } catch (e) {
      print("Error in fetchConnectionDetails: $e");
      _setError(e);
      return {
        'profile': null,
        'sharedCardPermission': 'casual',
        'mySharedCardToThem': 'casual',
      };
    }
  }

  Future<String> generateInviteCode(String sharedCardType) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      throw Exception("User is not signed in or profile is not loaded");
    }

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    final suffix = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
    final generatedCode = 'MNDL-$suffix';

    try {
      await _repository.insertInviteCode(generatedCode, currentUserId, sharedCardType);
      print("Successfully generated invite code: $generatedCode");
      return generatedCode;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<void> setQuickSetupComplete(bool val) async {
    quickSetupComplete = val;
    notifyListeners();
    final currentUserId = userId;
    if (currentUserId != null) {
      try {
        await _repository.updateProfileField(currentUserId, 'quick_setup_complete', val);
      } catch (e) {
        print("Error saving quickSetupComplete: $e");
      }
    }
  }

  void setVibeAndInterests(String vibe, List<String> interests) {
    vibeTag = vibe;
    interestTags = interests;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final myUserId = userId;
    final ownerUuid = Supabase.instance.client.auth.currentUser?.id;
    if (myUserId == null || ownerUuid == null) {
      throw Exception("User session not found");
    }

    final client = Supabase.instance.client;

    // Delete in order to prevent foreign key constraint violations
    // 1. Delete network_stats
    await client.from('network_stats').delete().eq('user_id', myUserId);

    // 2. Delete referral_requests where user is requester, target, or via
    await client.from('referral_requests').delete().eq('requester_id', myUserId);
    await client.from('referral_requests').delete().eq('target_id', myUserId);
    await client.from('referral_requests').delete().eq('via_user_id', myUserId);

    // 3. Delete profiles row — this cascades deletes user_connections, room_participants,
    // messages, user_push_tokens, invite_codes, and connection_notifications!
    await client.from('profiles').delete().eq('id', myUserId);

    // 4. Wipe local databases
    await LocalDatabaseHelper.instance.clearDatabaseForUser(myUserId);

    // 5. Clear SharedPreferences keys
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('owner_id');
    await prefs.remove('default_card_visibility');
    await prefs.remove('blur_background');

    // 6. Clear fields in Provider
    clearFields();

    // Set redirect flag
    showSignUpNext = true;

    // 7. Sign out of auth
    await client.auth.signOut();
  }

  Future<void> signOut() async {
    // Set redirect flag
    showSignUpNext = true;

    // 1. Sign out of Supabase auth first to trigger AuthGate redirect immediately
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print("SignOut: Error signing out of Supabase: $e");
    }

    // 2. Clear SharedPreferences keys (but NOT local chat database —
    //    messages are scoped by owner_id and preserved for when the user signs back in)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('owner_id');
      await prefs.remove('default_card_visibility');
      await prefs.remove('blur_background');
    } catch (e) {
      print("SignOut: Error clearing shared preferences: $e");
    }

    // 3. Clear fields in Provider
    clearFields();
  }
}
