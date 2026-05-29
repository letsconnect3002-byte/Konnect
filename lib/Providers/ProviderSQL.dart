import 'dart:convert';

import 'package:connect/Models/profile_card_type.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ProfileProvider2 with ChangeNotifier {
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
  bool showProfileToConnections = true;
  int userId = -1;

  List<Map<String, dynamic>> connections = [];
  RealtimeChannel? _connectionsSubscription;

  Map<String, dynamic> UserData = {};
  String? _ownerId;

  // Tracks if the profile is created
  bool isCreated = false;

  // Tracks edit state for each field
  Map<String, bool> editMode = {
    'name': false,
    'profession': false,
    'email': false,
    'professionalEmail': false,
    'phoneNumber': false,
    'professionalPhoneNumber': false,
    'instagram': false,
    'linkedin': false,
    'twitter': false,
    'company': false,
    'bio': false,
    'professionalBio': false,
  };

  /// Which card(s) each field appears on (Casual / Professional).
  Map<String, FieldCardAssignment> fieldAssignments = {};

  void _ensureDefaultFieldAssignments() {
    for (final field in assignableProfileFields) {
      fieldAssignments.putIfAbsent(
        field,
        () {
          if (field == 'email' || field == 'phoneNumber' || field == 'bio') {
            return FieldCardAssignment(casual: true, professional: true);
          }
          if (field == 'name' || field == 'avatarUrl') {
            return FieldCardAssignment(casual: true, professional: true);
          }
          return FieldCardAssignment(casual: false, professional: true);
        },
      );
    }
  }

  Future<void> loadFieldAssignments({bool forceLocal = false}) async {
    _ensureDefaultFieldAssignments();
    // Only load from SharedPreferences if we don't already have non-default assignments loaded from Supabase
    if (!forceLocal && fieldAssignments.values.any((v) => v.casual || !v.professional)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = userId != -1
        ? 'field_card_assignments_$userId'
        : 'field_card_assignments';
    final raw = prefs.getString(key);
    if (raw == null) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          fieldAssignments[entry.key] =
              FieldCardAssignment.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (e) {
      print('Error loading field assignments: $e');
    }
    notifyListeners();
  }

  Future<void> saveFieldAssignments() async {
    _ensureDefaultFieldAssignments();
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      fieldAssignments.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString('field_card_assignments', encoded);
    if (userId != -1) {
      await prefs.setString('field_card_assignments_$userId', encoded);
    }
  }

  bool isFieldOnCard(String field, ProfileCardType card) {
    final assignment = fieldAssignments[field];
    if (assignment == null) return card == ProfileCardType.professional;
    return card == ProfileCardType.casual
        ? assignment.casual
        : assignment.professional;
  }

  Future<void> toggleFieldOnCard(String field, ProfileCardType card) async {
    _ensureDefaultFieldAssignments();
    final current = fieldAssignments[field]!;
    if (card == ProfileCardType.casual) {
      fieldAssignments[field] =
          current.copyWith(casual: !current.casual);
    } else {
      fieldAssignments[field] =
          current.copyWith(professional: !current.professional);
    }
    notifyListeners();
    await saveFieldAssignments();
    if (userId != -1) {
      try {
        final assignmentsMap = fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
        await Supabase.instance.client.from('profiles').update({
          'field_assignments': assignmentsMap,
        }).eq('id', userId);
        print("Updated field assignments in Supabase");
      } catch (e) {
        print("Error saving field assignments to Supabase: $e");
      }
    }
  }

  Future<void> setFieldOnCard(String field, ProfileCardType card, bool enabled) async {
    _ensureDefaultFieldAssignments();
    final current = fieldAssignments[field]!;
    if (card == ProfileCardType.casual) {
      fieldAssignments[field] = current.copyWith(casual: enabled);
    } else {
      fieldAssignments[field] = current.copyWith(professional: enabled);
    }
    notifyListeners();
    await saveFieldAssignments();
    if (userId != -1) {
      try {
        final assignmentsMap = fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
        await Supabase.instance.client.from('profiles').update({
          'field_assignments': assignmentsMap,
        }).eq('id', userId);
        print("Updated field assignments in Supabase");
      } catch (e) {
        print("Error saving field assignments to Supabase: $e");
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
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('owner_id', ownerId)
          .eq('is_my_profile', true)
          .maybeSingle();

      if (response == null) {
        clearFields();
        name = session.user.email?.split('@')[0] ?? 'User';
        email = session.user.email ?? '';
        profession = 'Professional';
        isCreated = false;

        await saveProfileData(isMyProfile: true);
        print("Default profile created for owner ID: $ownerId");
      }
    } catch (e) {
      print("Error in ensureProfileExists: $e");
    }
  }

  void setUserData(Map<String, dynamic> data) {
    UserData = data;
    name = data['name'] ?? '';
    profession = data['profession'] ?? '';
    email = data['email'] ?? '';
    professionalEmail = data['professionalEmail'] ?? data['professional_email'] ?? '';
    phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? '';
    professionalPhoneNumber = data['professionalPhoneNumber'] ?? data['professional_phone_number'] ?? '';
    instagram = data['instagram'] ?? '';
    linkedin = data['linkedin'] ?? '';
    twitter = data['twitter'] ?? '';
    company = data['company'] ?? company;
    bio = data['bio'] ?? bio;
    professionalBio = data['professionalBio'] ?? data['professional_bio'] ?? '';
    avatarUrl = data['avatarUrl'] ?? data['avatar_url'] ?? avatarUrl;
    
    final showVal = data['showProfileToConnections'] ?? data['show_profile_to_connections'];
    if (showVal is bool) {
      showProfileToConnections = showVal;
    } else if (showVal is String) {
      showProfileToConnections = showVal == 'true';
    } else {
      showProfileToConnections = true;
    }
    notifyListeners();
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
    }
  }

  Future<void> setShowProfileToConnections(bool value) async {
    showProfileToConnections = value;
    notifyListeners();
    if (userId != -1) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'show_profile_to_connections': value,
        }).eq('id', userId);
        print("Updated show_profile_to_connections in Supabase to $value");
      } catch (e) {
        print("Error updating show_profile_to_connections in Supabase: $e");
      }
    }
  }

  // Method to fetch and set userId by profile type (isMyProfile)
  Future<void> fetchAndSetUserId(bool isMyProfile) async {
    userId = await fetchAndSetUserId2(isMyProfile);
    print("userId set to: $userId");
    if (userId != -1) {
      subscribeToConnections();
    }
    notifyListeners();
  }

  Future<int> fetchAndSetUserId2(bool isMyProfile) async {
    try {
      final ownerId = await _getOrCreateOwnerId();
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('owner_id', ownerId)
          .eq('is_my_profile', isMyProfile)
          .maybeSingle();

      if (response != null) {
        userId = response['id'] as int;
        subscribeToConnections();
        return userId;
      }
    } catch (e) {
      print("Error fetching user ID: $e");
    }
    userId = -1;
    return -1;
  }

  Future<List<Map<String, dynamic>>> getOtherProfiles() async {
    try {
      final myUserId = userId;
      if (myUserId == -1) {
        final ownerId = await _getOrCreateOwnerId();
        final me = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('owner_id', ownerId)
            .eq('is_my_profile', true)
            .maybeSingle();
        if (me != null) {
          userId = me['id'] as int;
        } else {
          return [];
        }
      }

      // Query the view to find connected user IDs
      final response = await Supabase.instance.client
          .from('network_graph')
          .select('connected_user_id, shared_card')
          .eq('primary_user_id', userId);

      if ((response as List).isEmpty) {
        return [];
      }

      // Build a lookup: connectedUserId -> sharedCard
      final Map<int, String> sharedCardLookup = {};
      for (final row in response as List) {
        sharedCardLookup[row['connected_user_id'] as int] =
            (row['shared_card'] ?? 'both').toString();
      }

      final connectedIds = (response as List).map<int>((row) => row['connected_user_id'] as int).toList();

      // Fetch the profiles for these IDs
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .filter('id', 'in', '(${connectedIds.join(",")})');

      return (profilesResponse as List).map((row) {
        return {
          'id': row['id'],
          'name': row['name'] ?? '',
          'profession': row['profession'] ?? '',
          'email': row['email'] ?? '',
          'professionalEmail': row['professional_email'] ?? '',
          'phoneNumber': row['phone_number'] ?? '',
          'professionalPhoneNumber': row['professional_phone_number'] ?? '',
          'instagram': row['instagram'] ?? '',
          'linkedin': row['linkedin'] ?? '',
          'twitter': row['twitter'] ?? '',
          'isMyProfile': row['is_my_profile'] == true,
          'created_at': row['created_at'],
          'company': row['company'] ?? '',
          'avatarUrl': row['avatar_url'] ?? '',
          'bio': row['bio'] ?? '',
          'professionalBio': row['professional_bio'] ?? '',
          'showProfileToConnections': row['show_profile_to_connections'] == true,
          'cardTypes': row['card_types'] != null
              ? List<String>.from(row['card_types'] as List)
              : <String>[],
          'connection_profile_id': row['id'],
          'shared_card': sharedCardLookup[row['id'] as int] ?? 'both',
          'field_assignments': row['field_assignments'], // pass raw jsonb through
        };
      }).toList();
    } catch (e) {
      print("Error fetching other profiles: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchConnections() async {
    final list = await getOtherProfiles();
    connections = list;
    notifyListeners();
    return list;
  }

  void subscribeToConnections() {
    if (userId == -1) return;
    unsubscribeFromConnections();

    _connectionsSubscription = Supabase.instance.client
        .channel('public:user_connections_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_connections',
          callback: (payload) async {
            print("Realtime connection change detected: ${payload.toString()}");
            await fetchConnections();
          },
        );

    _connectionsSubscription?.subscribe();

    // Initial fetch to load the data
    fetchConnections();
  }

  void unsubscribeFromConnections() {
    if (_connectionsSubscription != null) {
      Supabase.instance.client.removeChannel(_connectionsSubscription!);
      _connectionsSubscription = null;
    }
  }

  @override
  void dispose() {
    unsubscribeFromConnections();
    super.dispose();
  }

  // Method to fetch and set userId by email
  Future<void> fetchAndSetUserIdEmail(String email) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        userId = response['id'] as int;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching user ID by email: $e");
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
      "company": "",
      "bio": "",
      "professionalBio": "",
      "avatarUrl": "",
      "showProfileToConnections": true
    };
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

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
        company = response['company'] ?? '';
        bio = response['bio'] ?? '';
        professionalBio = response['professional_bio'] ?? '';
        avatarUrl = response['avatar_url'] ?? '';
        showProfileToConnections = response['show_profile_to_connections'] == true;

        profileData["name"] = name;
        profileData["profession"] = profession;
        profileData["email"] = email;
        profileData["professionalEmail"] = professionalEmail;
        profileData["phoneNumber"] = phoneNumber;
        profileData["professionalPhoneNumber"] = professionalPhoneNumber;
        profileData["instagram"] = instagram;
        profileData["linkedin"] = linkedin;
        profileData["twitter"] = twitter;
        profileData["company"] = company;
        profileData["bio"] = bio;
        profileData["professionalBio"] = professionalBio;
        profileData["avatarUrl"] = avatarUrl;
        profileData["showProfileToConnections"] = showProfileToConnections;

        isCreated = true;

        // Load field assignments from database if present
        if (response['field_assignments'] != null) {
          try {
            final Map<String, dynamic> decoded = response['field_assignments'] is String
                ? jsonDecode(response['field_assignments'] as String) as Map<String, dynamic>
                : response['field_assignments'] as Map<String, dynamic>;
            _ensureDefaultFieldAssignments();
            for (final entry in decoded.entries) {
              if (entry.value is Map<String, dynamic>) {
                fieldAssignments[entry.key] =
                    FieldCardAssignment.fromJson(entry.value as Map<String, dynamic>);
              }
            }
            // Keep local prefs in sync
            await saveFieldAssignments();
          } catch (e) {
            print("Error parsing field_assignments: $e");
          }
        } else {
          _ensureDefaultFieldAssignments();
        }

        notifyListeners();
        return profileData; // Return early since DB loaded successfully
      }
      
      // Fallback only if profile doesn't exist in Supabase
      await loadFieldAssignments(forceLocal: true);
    } catch (e) {
      print("Error loading profile: $e");
    }
    return profileData;
  }

  // Save profile data to the database
  Future<void> saveProfileData({bool isMyProfile = true}) async {
    if (!isCreated) {
      try {
        final ownerId = await _getOrCreateOwnerId();
        _ensureDefaultFieldAssignments();
        final assignmentsMap = fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));

        final response = await Supabase.instance.client
            .from('profiles')
            .insert({
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
              'is_my_profile': isMyProfile,
              'company': company,
              'bio': bio,
              'professional_bio': professionalBio,
              'avatar_url': avatarUrl,
              'show_profile_to_connections': showProfileToConnections,
              'field_assignments': assignmentsMap,
            })
            .select('id')
            .single();

        userId = response['id'] as int;
        isCreated = true;
        notifyListeners();
        print("inserted");
        print({
          'name': name,
          'profession': profession,
          'email': email,
          'professionalEmail': professionalEmail,
          'phoneNumber': phoneNumber,
          'professionalPhoneNumber': professionalPhoneNumber,
          'instagram': instagram,
          'linkedin': linkedin,
          'twitter': twitter,
          'isMyProfile': isMyProfile,
          'company': company,
          'bio': bio,
          'professionalBio': professionalBio,
          'avatarUrl': avatarUrl,
          'showProfileToConnections': showProfileToConnections,
          'field_assignments': assignmentsMap,
        });
      } catch (e) {
        print("Error saving profile data: $e");
      }
    }
  }

  Future<void> saveOtherProfileData(
      bool isMyProfile, Map<String, dynamic> profileData, {int? connectionProfileId}) async {
    try {
      final ownerId = await _getOrCreateOwnerId();
      await Supabase.instance.client.from('profiles').insert({
        'owner_id': ownerId,
        'name': profileData['name'] ?? '',
        'profession': profileData['profession'] ?? '',
        'email': profileData['email'] ?? '',
        'professional_email': profileData['professionalEmail'] ?? '',
        'phone_number': profileData['phoneNumber'] ?? '',
        'professional_phone_number': profileData['professionalPhoneNumber'] ?? '',
        'instagram': profileData['instagram'] ?? '',
        'linkedin': profileData['linkedin'] ?? '',
        'twitter': profileData['twitter'] ?? '',
        'is_my_profile': isMyProfile,
        'company': profileData['company'] ?? '',
        'bio': profileData['bio'] ?? '',
        'professional_bio': profileData['professionalBio'] ?? '',
        'avatar_url': profileData['avatarUrl'] ?? '',
        'show_profile_to_connections': profileData['showProfileToConnections'] == true || profileData['showProfileToConnections'] == 'true',
        'card_types': profileData['cardTypes'] ?? profileData['card_types'] ?? [],
        'connection_profile_id': connectionProfileId ?? profileData['id'],
      });
      notifyListeners();
      print("inserted scanned connection");
    } catch (e) {
      print("Error saving scanned connection: $e");
    }
  }

  // Update a specific field in the profile
  Future<void> updateProfileField(String field, String value, int id) async {
    // Update locally
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
    }

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
    }

    try {
      // Update in the database
      await Supabase.instance.client.from('profiles').update({
        dbField: value,
      }).eq('id', id);

      // Keep UserData local cache updated
      UserData[field] = value;
      print("Updated field $field in database to $value");
    } catch (e) {
      print("Error updating profile field: $e");
    }

    // Exit edit mode for the field
    if (editMode.containsKey(field)) {
      editMode[field] = false;
    }
    notifyListeners();
  }

  // Delete a specific profile by id
  Future<void> deleteProfile(int id) async {
    if (id == userId) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', id);
        clearFields();
        print("Deleted my profile with id: $id");
      } catch (e) {
        print("Error deleting my profile: $e");
      }
    } else {
      // If it's someone else's profile, disconnect instead of deleting the profile
      await disconnectUsers(userId, id);
    }
    notifyListeners();
  }

  Future<void> connectUsers(int idA, int idB, {String? sharedCardByPresenter, String? sharedCardByScanner}) async {
    if (idA == idB) {
      print("Cannot connect a user to themselves");
      return;
    }
    final int id1 = idA < idB ? idA : idB;
    final int id2 = idA > idB ? idA : idB;

    String u1Share = 'both';
    String u2Share = 'both';

    if (idA < idB) {
      // idA is user_id_1 (scanner), idB is user_id_2 (presenter)
      u1Share = sharedCardByScanner ?? 'both';
      u2Share = sharedCardByPresenter ?? 'both';
    } else {
      // idB is user_id_1 (presenter), idA is user_id_2 (scanner)
      u1Share = sharedCardByPresenter ?? 'both';
      u2Share = sharedCardByScanner ?? 'both';
    }

    try {
      await Supabase.instance.client.from('user_connections').upsert({
        'user_id_1': id1,
        'user_id_2': id2,
        'user_1_shared_card': u1Share,
        'user_2_shared_card': u2Share,
      });
      print("Successfully connected user $id1 and user $id2 (shares: $u1Share, $u2Share)");
      notifyListeners();
    } catch (e) {
      print("Error connecting users: $e");
      rethrow;
    }
  }

  Future<void> updateConnectionAccess(int otherUserId, String newAccessType) async {
    final myUserId = userId;
    if (myUserId == -1) return;

    final int id1 = myUserId < otherUserId ? myUserId : otherUserId;
    final int id2 = myUserId > otherUserId ? myUserId : otherUserId;

    final String columnToUpdate = myUserId < otherUserId ? 'user_1_shared_card' : 'user_2_shared_card';

    try {
      await Supabase.instance.client
          .from('user_connections')
          .update({columnToUpdate: newAccessType})
          .eq('user_id_1', id1)
          .eq('user_id_2', id2);
      print("Updated connection access: $myUserId shares $newAccessType with $otherUserId");
      notifyListeners();
    } catch (e) {
      print("Error updating connection access: $e");
      rethrow;
    }
  }

  Future<void> disconnectUsers(int idA, int idB) async {
    final int id1 = idA < idB ? idA : idB;
    final int id2 = idA > idB ? idA : idB;
    try {
      await Supabase.instance.client
          .from('user_connections')
          .delete()
          .eq('user_id_1', id1)
          .eq('user_id_2', id2);
      print("Successfully disconnected user $id1 and user $id2");
      notifyListeners();
    } catch (e) {
      print("Error disconnecting users: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchProfileDataOnly(int id) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

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
          'isMyProfile': response['is_my_profile'] == true,
          'created_at': response['created_at'],
          'company': response['company'] ?? '',
          'avatarUrl': response['avatar_url'] ?? '',
          'bio': response['bio'] ?? '',
          'professionalBio': response['professional_bio'] ?? '',
          'showProfileToConnections': response['show_profile_to_connections'] == true,
          'cardTypes': response['card_types'] != null
              ? List<String>.from(response['card_types'] as List)
              : <String>[],
          'connection_profile_id': response['id'],
          'field_assignments': response['field_assignments'],
        };
      }
    } catch (e) {
      print("Error fetching profile data only: $e");
    }
    return {};
  }

  // Toggle edit mode for a specific field
  void toggleEditMode(String field) {
    editMode[field] = !editMode[field]!;
    notifyListeners();
  }

  // Set explicit edit mode for a specific field
  void setEditMode(String field, bool value) {
    if (editMode[field] != value) {
      editMode[field] = value;
      notifyListeners();
    }
  }

  // Save or update all profile fields at once
  Future<void> saveOrUpdateProfile() async {
    final ownerId = await _getOrCreateOwnerId();
    _ensureDefaultFieldAssignments();
    final assignmentsMap = fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));

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
      'company': company,
      'bio': bio,
      'professional_bio': professionalBio,
      'avatar_url': avatarUrl,
      'show_profile_to_connections': showProfileToConnections,
      'field_assignments': assignmentsMap,
    };

    try {
      if (userId != -1) {
        // Update existing profile
        await Supabase.instance.client
            .from('profiles')
            .update(data)
            .eq('id', userId);
        
        UserData = {
          'id': userId,
          'name': name,
          'profession': profession,
          'email': email,
          'professionalEmail': professionalEmail,
          'phoneNumber': phoneNumber,
          'professionalPhoneNumber': professionalPhoneNumber,
          'instagram': instagram,
          'linkedin': linkedin,
          'twitter': twitter,
          'company': company,
          'bio': bio,
          'professionalBio': professionalBio,
          'avatarUrl': avatarUrl,
          'showProfileToConnections': showProfileToConnections,
          'field_assignments': assignmentsMap,
        };

        print("Profile updated successfully in Supabase");
      } else {
        // Insert new profile
        final response = await Supabase.instance.client
            .from('profiles')
            .insert({
              ...data,
              'owner_id': ownerId,
              'is_my_profile': true,
            })
            .select('id')
            .single();

        userId = response['id'] as int;
        isCreated = true;
        UserData = {
          'id': userId,
          'name': name,
          'profession': profession,
          'email': email,
          'professionalEmail': professionalEmail,
          'phoneNumber': phoneNumber,
          'professionalPhoneNumber': professionalPhoneNumber,
          'instagram': instagram,
          'linkedin': linkedin,
          'twitter': twitter,
          'company': company,
          'bio': bio,
          'professionalBio': professionalBio,
          'avatarUrl': avatarUrl,
          'showProfileToConnections': showProfileToConnections,
          'field_assignments': assignmentsMap,
        };

        print("Profile created successfully in Supabase with id: $userId");
      }
      await saveFieldAssignments();
    } catch (e) {
      print("Error saving/updating profile in Supabase: $e");
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
    company = '';
    bio = '';
    professionalBio = '';
    avatarUrl = '';
    showProfileToConnections = true;
    isCreated = false;
    userId = -1;
    UserData = {};
  }
}
