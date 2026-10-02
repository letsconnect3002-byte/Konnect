import 'dart:convert';
import 'dart:math';

import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:connect/Models/profile_card_type.dart';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Models/custom_link.dart';
import 'package:connect/Models/resume_models.dart';
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

  bool _isChatView = false;
  bool get isChatView => _isChatView;

  Future<void> setIsChatView(bool val) async {
    if (_isChatView == val) return;
    _isChatView = val;
    notifyListeners();

    final myUserId = userId;
    if (myUserId != null) {
      try {
        await _repository.updateProfileField(myUserId, 'is_chat_view', val);
      } catch (_) {}
    }
  }

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
  String anonName = '';
  String gender = '';
  String spotify = '';
  String handle = '';
  List<CustomLink> customLinks = [];
  List<ExperienceItem> experience = [];
  List<EducationItem> education = [];
  List<String> skills = [];
  bool showProfileToConnections = true;

  // Quick Identity fields
  String vibeTag = '';
  List<String> interestTags = [];
  bool quickSetupComplete = false;
  bool showSignUpNext = false;

  /// Returns company dynamically mapped to the Experience list item where
  /// the date is marked as `<Date> - Present` (or isCurrent == true).
  String get currentCompany {
    for (final exp in experience) {
      if (exp.isCurrent ||
          exp.endDate.trim().toLowerCase() == 'present' ||
          exp.endDate.toLowerCase().contains('present')) {
        if (exp.company.trim().isNotEmpty) {
          return exp.company.trim();
        }
      }
    }
    return company.trim();
  }

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
    anonName = '';
    gender = '';
    handle = '';
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
          if (field == 'name' || field == 'avatarUrl' || field == 'email') {
            return FieldCardAssignment(casual: true, professional: true);
          }
          return FieldCardAssignment(casual: false, professional: true);
        },
      );
    }
  }

  bool isFieldOnCard(String field, [ProfileCardType? card]) {
    _ensureDefaultFieldAssignments();
    final assignment = fieldAssignments[field];
    if (assignment != null && assignment.isPrivate) {
      return false;
    }
    return true;
  }

  Future<void> toggleFieldOnCard(String field, [ProfileCardType? card]) async {
    _ensureDefaultFieldAssignments();
    fieldAssignments.putIfAbsent(
        field, () => FieldCardAssignment(casual: true, professional: true, isPrivate: false));
    final current = fieldAssignments[field]!;
    fieldAssignments[field] = current.copyWith(
      isPrivate: !current.isPrivate,
      casual: true,
      professional: true,
    );
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
        field, () => FieldCardAssignment(casual: true, professional: true, isPrivate: false));
    final current = fieldAssignments[field]!;
    fieldAssignments[field] = current.copyWith(
      isPrivate: !enabled,
      casual: true,
      professional: true,
    );
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
      case 'handle':
        return handle;
      default:
        return null;
    }
  }

  // Helper to generate a URL-safe handle slug
  static String generateHandleSlug(String input) {
    var s = input.toLowerCase().trim().replaceAll('@', '');
    s = s.replaceAll(RegExp(r'[^a-z0-9_.-]+'), '');
    return s.isEmpty ? 'user' : s;
  }

  // Generates a smart handle with "name<4 digits>" combining date/time and unique user ID
  static String generateSmartHandle({
    required String baseName,
    required String ownerId,
    DateTime? dateTime,
  }) {
    var clean = baseName.toLowerCase().trim().replaceAll('@', '');
    clean = clean.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (clean.isEmpty || clean == 'user') {
      clean = 'user';
    }

    final ts = (dateTime ?? DateTime.now()).toUtc();
    // 2 digits smartly derived from date and time (range: 10 - 99)
    final int timeNum = ((ts.day * 60 + ts.minute) % 90) + 10;

    // 2 digits smartly derived from unique ID (range: 10 - 99)
    final cleanId = ownerId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    int idValue = 0;
    if (cleanId.length >= 4) {
      idValue = int.tryParse(cleanId.substring(cleanId.length - 4), radix: 16) ?? 0;
    } else {
      idValue = ownerId.hashCode.abs();
    }
    final int idNum = (idValue % 90) + 10;

    // Deterministic 4-digit number: 1010 - 9999
    final int fourDigitNumber = (timeNum * 100) + idNum;
    return '$clean$fourDigitNumber';
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
      final metadata = session.user.userMetadata ?? {};
      final String? metaAvatar = metadata['avatar_url']?.toString() ??
          metadata['picture']?.toString();
      final String? metaName = metadata['full_name']?.toString() ??
          metadata['name']?.toString();

      if (list.isEmpty) {
        clearFields();
        name = (metaName != null && metaName.trim().isNotEmpty)
            ? metaName.trim()
            : (session.user.email?.split('@')[0] ?? 'User');
        email = session.user.email ?? '';
        avatarUrl = (metaAvatar != null && metaAvatar.trim().isNotEmpty)
            ? metaAvatar.trim()
            : '';
        profession = 'Professional';
        gender = metadata['gender'] as String? ?? '';

        final rawBase = (name.isNotEmpty && name.toLowerCase() != 'user')
            ? name
            : (email.isNotEmpty ? email.split('@')[0] : 'user');
        handle = generateSmartHandle(
          baseName: rawBase,
          ownerId: ownerId,
        );

        _setLoadedState(0, false);
        await saveProfileData(isMyProfile: true);
        print("Default profile created for owner ID: $ownerId with avatar: $avatarUrl, handle: $handle");
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
      case 'handle':
        handle = generateHandleSlug(value);
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

  // Experience CRUD
  Future<void> addExperience(ExperienceItem item) async {
    experience.add(item);
    if (currentCompany.isNotEmpty) {
      company = currentCompany;
    }
    notifyListeners();
    await saveOrUpdateProfile();
  }

  Future<void> updateExperience(ExperienceItem item) async {
    final idx = experience.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      experience[idx] = item;
      if (currentCompany.isNotEmpty) {
        company = currentCompany;
      }
      notifyListeners();
      await saveOrUpdateProfile();
    }
  }

  Future<void> deleteExperience(String id) async {
    experience.removeWhere((e) => e.id == id);
    company = currentCompany;
    notifyListeners();
    await saveOrUpdateProfile();
  }

  // Education CRUD
  Future<void> addEducation(EducationItem item) async {
    education.add(item);
    notifyListeners();
    await saveOrUpdateProfile();
  }

  Future<void> updateEducation(EducationItem item) async {
    final idx = education.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      education[idx] = item;
      notifyListeners();
      await saveOrUpdateProfile();
    }
  }

  Future<void> deleteEducation(String id) async {
    education.removeWhere((e) => e.id == id);
    notifyListeners();
    await saveOrUpdateProfile();
  }

  // Skills CRUD
  Future<void> setSkills(List<String> newSkills) async {
    skills = newSkills;
    notifyListeners();
    await saveOrUpdateProfile();
  }

  Future<void> addSkill(String skill) async {
    final trimmed = skill.trim();
    if (trimmed.isNotEmpty && !skills.contains(trimmed)) {
      skills.add(trimmed);
      notifyListeners();
      await saveOrUpdateProfile();
    }
  }

  Future<void> removeSkill(String skill) async {
    skills.remove(skill);
    notifyListeners();
    await saveOrUpdateProfile();
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
        handle = response['handle']?.toString() ?? '';
        profileData['handle'] = handle;

        // Auto-backfill avatar, name, and handle from Google/OAuth metadata if not yet set
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.user.id == _ownerId) {
          final metadata = session.user.userMetadata ?? {};
          final String? metaAvatar = metadata['avatar_url']?.toString() ??
              metadata['picture']?.toString();
          if (avatarUrl.trim().isEmpty && metaAvatar != null && metaAvatar.trim().isNotEmpty) {
            avatarUrl = metaAvatar.trim();
            profileData['avatarUrl'] = avatarUrl;
            _repository.updateProfileField(id, 'avatar_url', avatarUrl).catchError((e) {
              debugPrint("Error auto-updating avatar from OAuth metadata: $e");
            });
          }
          final String? metaName = metadata['full_name']?.toString() ??
              metadata['name']?.toString();
          if ((name.trim().isEmpty || name == 'User' || name == email.split('@')[0]) &&
              metaName != null &&
              metaName.trim().isNotEmpty) {
            name = metaName.trim();
            profileData['name'] = name;
            _repository.updateProfileField(id, 'name', name).catchError((e) {
              debugPrint("Error auto-updating name from OAuth metadata: $e");
            });
          }
          if (handle.trim().isEmpty) {
            final rawBase = (name.isNotEmpty && name.toLowerCase() != 'user')
                ? name
                : (email.isNotEmpty ? email.split('@')[0] : 'user');
            handle = generateSmartHandle(
              baseName: rawBase,
              ownerId: _ownerId ?? '',
            );
            profileData['handle'] = handle;
            _repository.updateProfileField(id, 'handle', handle).catchError((e) {
              debugPrint("Error auto-updating handle: $e");
            });
          }
        }
        anonName = response['anon_name']?.toString() ?? '';
        gender = response['gender'] ?? '';
        showProfileToConnections =
            response['show_profile_to_connections'] == true;
        _isChatView = response['is_chat_view'] == true;
        profileData['is_chat_view'] = _isChatView;

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

        experience = [];
        if (response['experience'] != null) {
          try {
            final List<dynamic> decoded = response['experience'] is String
                ? jsonDecode(response['experience'] as String) as List<dynamic>
                : response['experience'] as List<dynamic>;
            experience = decoded.map((item) => ExperienceItem.fromJson(item as Map<String, dynamic>)).toList();
            if (currentCompany.isNotEmpty) {
              company = currentCompany;
            }
          } catch (e) {
            print("Error parsing experience: $e");
          }
        }

        education = [];
        if (response['education'] != null) {
          try {
            final List<dynamic> decoded = response['education'] is String
                ? jsonDecode(response['education'] as String) as List<dynamic>
                : response['education'] as List<dynamic>;
            education = decoded.map((item) => EducationItem.fromJson(item as Map<String, dynamic>)).toList();
          } catch (e) {
            print("Error parsing education: $e");
          }
        }

        skills = [];
        if (response['skills'] != null) {
          try {
            final List<dynamic> decoded = response['skills'] is String
                ? jsonDecode(response['skills'] as String) as List<dynamic>
                : response['skills'] as List<dynamic>;
            skills = decoded.map((item) => item.toString()).toList();
          } catch (e) {
            print("Error parsing skills: $e");
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
        profileData["experience"] = experience.map((e) => e.toJson()).toList();
        profileData["education"] = education.map((e) => e.toJson()).toList();
        profileData["skills"] = skills;
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
          'company': currentCompany.isNotEmpty ? currentCompany : company,
          'bio': bio,
          'professional_bio': professionalBio,
          'avatar_url': avatarUrl,
          'gender': gender,
          if (handle.isNotEmpty) 'handle': handle,
          'show_profile_to_connections': showProfileToConnections,
          'field_assignments': assignmentsMap,
          'custom_links': customLinks.map((l) => l.toJson()).toList(),
          'experience': experience.map((e) => e.toJson()).toList(),
          'education': education.map((e) => e.toJson()).toList(),
          'skills': skills,
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
      'company': currentCompany.isNotEmpty ? currentCompany : company,
      'bio': bio,
      'professional_bio': professionalBio,
      'avatar_url': avatarUrl,
      if (handle.isNotEmpty) 'handle': handle,
      'show_profile_to_connections': showProfileToConnections,
      'field_assignments': assignmentsMap,
      'custom_links': customLinks.map((l) => l.toJson()).toList(),
      'experience': experience.map((e) => e.toJson()).toList(),
      'education': education.map((e) => e.toJson()).toList(),
      'skills': skills,
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
    experience = [];
    education = [];
    skills = [];
    company = '';
    bio = '';
    professionalBio = '';
    avatarUrl = '';
    anonName = '';
    gender = '';
    showProfileToConnections = true;
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
          'experience': response['experience'] != null
              ? (response['experience'] is String
                  ? jsonDecode(response['experience'] as String) as List<dynamic>
                  : response['experience'] as List<dynamic>)
              : <dynamic>[],
          'education': response['education'] != null
              ? (response['education'] is String
                  ? jsonDecode(response['education'] as String) as List<dynamic>
                  : response['education'] as List<dynamic>)
              : <dynamic>[],
          'skills': response['skills'] != null
              ? (response['skills'] is String
                  ? jsonDecode(response['skills'] as String) as List<dynamic>
                  : response['skills'] as List<dynamic>)
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

  Future<String> generateInviteCode(
    String sharedCardType, {
    String keyType = 'single_use',
  }) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      throw Exception("User is not signed in or profile is not loaded");
    }

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    final suffix = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
    final generatedCode = 'MNDL-$suffix';

    final DateTime? expiresAt = keyType == 'group_24h'
        ? DateTime.now().toUtc().add(const Duration(hours: 24))
        : null;

    try {
      await _repository.insertInviteCode(
        generatedCode,
        currentUserId,
        sharedCardType,
        keyType: keyType,
        expiresAt: expiresAt,
      );
      print("Successfully generated invite code: $generatedCode (type: $keyType, expires: $expiresAt)");
      return generatedCode;
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchActiveInviteCode({String? keyType}) async {
    final currentUserId = userId;
    if (currentUserId == null) return null;
    return await _repository.fetchActiveInviteCode(currentUserId, keyType: keyType);
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
