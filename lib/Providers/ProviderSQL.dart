import 'dart:convert';
import 'dart:math';

import 'package:connect/Models/profile_card_type.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:connect/Providers/LocalDatabaseHelper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connect/main.dart';

class ProfileProvider2 with ChangeNotifier {
  int totalUnreadCount = 0;
  int casualUnreadCount = 0;
  int professionalUnreadCount = 0;

  Future<void> updateUnreadCount() async {
    final myUserId = userId;
    if (myUserId == -1) {
      totalUnreadCount = 0;
      casualUnreadCount = 0;
      professionalUnreadCount = 0;
      return;
    }
    try {
      final db = await LocalDatabaseHelper.instance.database;

      // 1. Get total unread count
      final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM messages WHERE sender_id != ? AND status != 'read'",
        [myUserId],
      );
      if (result.isNotEmpty) {
        totalUnreadCount = Sqflite.firstIntValue(result) ?? 0;
      } else {
        totalUnreadCount = 0;
      }

      // 2. Get unread messages grouped by room_id
      final List<Map<String, dynamic>> roomResults = await db.rawQuery(
        "SELECT room_id, COUNT(*) as count FROM messages WHERE sender_id != ? AND status != 'read' GROUP BY room_id",
        [myUserId],
      );

      final Map<String, int> roomUnreadMap = {
        for (final row in roomResults)
          row['room_id'] as String: int.tryParse(row['count'].toString()) ?? 0
      };

      // 3. Map to tabs
      int casualCount = 0;
      int professionalCount = 0;

      for (final connection in connections) {
        final int connId = connection['id'] as int;
        final String? rId = connectionRooms[connId];
        if (rId != null && roomUnreadMap.containsKey(rId)) {
          final int count = roomUnreadMap[rId]!;

          // Determine tab assignments
          final sharedCard = (connection['my_shared_card'] ??
                  connection['shared_card'] ??
                  connection['sharedCard'] ??
                  'both')
              .toString()
              .toLowerCase();

          if (sharedCard == 'casual') {
            casualCount += count;
          } else if (sharedCard == 'professional') {
            professionalCount += count;
          } else {
            // both
            casualCount += count;
            professionalCount += count;
          }
        }
      }

      casualUnreadCount = casualCount;
      professionalUnreadCount = professionalCount;

      notifyListeners();
    } catch (e) {
      print("Error calculating unread count: $e");
    }
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
    if (!forceLocal &&
        fieldAssignments.values.any((v) => v.casual || !v.professional)) {
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
      fieldAssignments[field] = current.copyWith(casual: !current.casual);
    } else {
      fieldAssignments[field] =
          current.copyWith(professional: !current.professional);
    }
    notifyListeners();
    await saveFieldAssignments();
    if (userId != -1) {
      try {
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
        await Supabase.instance.client.from('profiles').update({
          'field_assignments': assignmentsMap,
        }).eq('id', userId);
        print("Updated field assignments in Supabase");
      } catch (e) {
        print("Error saving field assignments to Supabase: $e");
      }
    }
  }

  Future<void> setFieldOnCard(
      String field, ProfileCardType card, bool enabled) async {
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
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));
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
        gender = session.user.userMetadata?['gender'] as String? ?? '';
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
    professionalEmail =
        data['professionalEmail'] ?? data['professional_email'] ?? '';
    phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? '';
    professionalPhoneNumber = data['professionalPhoneNumber'] ??
        data['professional_phone_number'] ??
        '';
    instagram = data['instagram'] ?? '';
    linkedin = data['linkedin'] ?? '';
    twitter = data['twitter'] ?? '';
    company = data['company'] ?? company;
    bio = data['bio'] ?? bio;
    professionalBio = data['professionalBio'] ?? data['professional_bio'] ?? '';
    avatarUrl = data['avatarUrl'] ?? data['avatar_url'] ?? avatarUrl;
    gender = data['gender'] ?? '';

    final showVal =
        data['showProfileToConnections'] ?? data['show_profile_to_connections'];
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
      case 'gender':
        gender = value;
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

      // Query user_connections directly to get connections and permissions
      final response = await Supabase.instance.client
          .from('user_connections')
          .select(
              'user_id_1, user_id_2, user_1_shared_card, user_2_shared_card')
          .or('user_id_1.eq.$myUserId,user_id_2.eq.$myUserId');

      if ((response as List).isEmpty) {
        return [];
      }

      // Build lookups: connectedUserId -> sharedCard (what they share with me), mySharedCard (what I share with them)
      final Map<int, String> sharedCardLookup = {};
      final Map<int, String> mySharedCardLookup = {};
      final List<int> connectedIds = [];

      for (final row in response as List) {
        final int id1 = row['user_id_1'] as int;
        final int id2 = row['user_id_2'] as int;
        final int otherId = (id1 == myUserId) ? id2 : id1;
        connectedIds.add(otherId);

        if (id1 == myUserId) {
          mySharedCardLookup[otherId] =
              (row['user_1_shared_card'] ?? 'both').toString();
          sharedCardLookup[otherId] =
              (row['user_2_shared_card'] ?? 'both').toString();
        } else {
          mySharedCardLookup[otherId] =
              (row['user_2_shared_card'] ?? 'both').toString();
          sharedCardLookup[otherId] =
              (row['user_1_shared_card'] ?? 'both').toString();
        }
      }

      if (connectedIds.isEmpty) {
        return [];
      }

      // Fetch the profiles for these IDs
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .filter('id', 'in', '(${connectedIds.join(",")})');

      return (profilesResponse as List).map((row) {
        final int profileId = row['id'] as int;
        return {
          'id': profileId,
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
          'showProfileToConnections':
              row['show_profile_to_connections'] == true,
          'cardTypes': row['card_types'] != null
              ? List<String>.from(row['card_types'] as List)
              : <String>[],
          'connection_profile_id': profileId,
          'shared_card': sharedCardLookup[profileId] ?? 'both',
          'my_shared_card': mySharedCardLookup[profileId] ?? 'both',
          'field_assignments':
              row['field_assignments'], // pass raw jsonb through
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
            await updateUnreadCount();
          },
        );

    _connectionsSubscription?.subscribe();

    // Initial fetch to load the data, then load chat rooms to ensure connections list is loaded first
    fetchConnections().then((_) {
      loadChatRooms();
    });
  }

  void unsubscribeFromConnections() {
    if (_connectionsSubscription != null) {
      Supabase.instance.client.removeChannel(_connectionsSubscription!);
      _connectionsSubscription = null;
    }
    for (final channel in _roomSubscriptions.values) {
      Supabase.instance.client.removeChannel(channel);
    }
    _roomSubscriptions.clear();
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
      "gender": "",
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
        gender = response['gender'] ?? '';
        showProfileToConnections =
            response['show_profile_to_connections'] == true;

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
        profileData["gender"] = gender;
        profileData["showProfileToConnections"] = showProfileToConnections;

        isCreated = true;

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
        final assignmentsMap =
            fieldAssignments.map((k, v) => MapEntry(k, v.toJson()));

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
              'gender': gender,
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
      bool isMyProfile, Map<String, dynamic> profileData,
      {int? connectionProfileId}) async {
    try {
      final ownerId = await _getOrCreateOwnerId();
      await Supabase.instance.client.from('profiles').insert({
        'owner_id': ownerId,
        'name': profileData['name'] ?? '',
        'profession': profileData['profession'] ?? '',
        'email': profileData['email'] ?? '',
        'professional_email': profileData['professionalEmail'] ?? '',
        'phone_number': profileData['phoneNumber'] ?? '',
        'professional_phone_number':
            profileData['professionalPhoneNumber'] ?? '',
        'instagram': profileData['instagram'] ?? '',
        'linkedin': profileData['linkedin'] ?? '',
        'twitter': profileData['twitter'] ?? '',
        'is_my_profile': isMyProfile,
        'company': profileData['company'] ?? '',
        'bio': profileData['bio'] ?? '',
        'professional_bio': profileData['professionalBio'] ?? '',
        'avatar_url': profileData['avatarUrl'] ?? '',
        'show_profile_to_connections':
            profileData['showProfileToConnections'] == true ||
                profileData['showProfileToConnections'] == 'true',
        'card_types':
            profileData['cardTypes'] ?? profileData['card_types'] ?? [],
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
      case 'gender':
        gender = value;
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

  // Delete a specific profile by id and clear all associated chat history
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
      // If it's someone else's profile, disconnect and clear all chat history
      try {
        final String? roomId = connectionRooms[id];

        // 1. Disconnect the users
        await disconnectUsers(userId, id);

        // 2. Clear SQLite local messages
        if (roomId != null) {
          final db = await LocalDatabaseHelper.instance.database;
          await db.delete(
            'messages',
            where: 'room_id = ?',
            whereArgs: [roomId],
          );
        }

        // 3. Clear Supabase messages/room
        if (roomId != null) {
          try {
            await Supabase.instance.client
                .from('messages')
                .delete()
                .eq('room_id', roomId);
            await Supabase.instance.client
                .from('room_participants')
                .delete()
                .eq('room_id', roomId);
            await Supabase.instance.client
                .from('chat_rooms')
                .delete()
                .eq('id', roomId);
          } catch (dbErr) {
            print("Note: Supabase room clean up restricted/skipped: $dbErr");
          }
        }

        // 4. Update memory cache
        connectionRooms.remove(id);
        if (activeRoomId == roomId) {
          activeRoomId = null;
          activeRoomMessages = [];
        }

        await fetchConnections();
        await updateUnreadCount();
      } catch (e) {
        print("Error deleting someone else's profile/chat: $e");
        rethrow;
      }
    }
    notifyListeners();
  }

  Future<String> generateInviteCode(String sharedCardType) async {
    if (userId == -1) {
      throw Exception("User is not signed in or profile is not loaded");
    }
    
    // Generate a random 6-character alphanumeric code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    final suffix = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
    final generatedCode = 'MNDL-$suffix';
    
    try {
      await Supabase.instance.client.from('invite_codes').insert({
        'code': generatedCode,
        'sender_id': userId,
        'shared_card_type': sharedCardType,
        'is_used': false,
      });
      print("Successfully generated invite code: $generatedCode");
      return generatedCode;
    } catch (e) {
      print("Error generating invite code: $e");
      rethrow;
    }
  }

  Future<int> redeemInviteCode(String code, String mySharedCardType) async {
    if (userId == -1) {
      throw Exception("User is not signed in or profile is not loaded");
    }

    try {
      // 1. Query the code
      final response = await Supabase.instance.client
          .from('invite_codes')
          .select()
          .eq('code', code.trim().toUpperCase())
          .eq('is_used', false)
          .maybeSingle();

      if (response == null) {
        throw Exception("Invalid or already used code");
      }

      final int senderId = response['sender_id'] as int;
      final String sharedCardType = response['shared_card_type'] as String;

      // 2. Connect users
      // Note: myUserId (userId) is the scanner/redeemer, and senderId is the presenter.
      await connectUsers(
        userId,
        senderId,
        sharedCardByPresenter: sharedCardType,
        sharedCardByScanner: mySharedCardType,
      );

      // 3. Mark the code as used
      await Supabase.instance.client
          .from('invite_codes')
          .update({'is_used': true})
          .eq('id', response['id']);

      print("Successfully redeemed invite code: $code");
      return senderId;
    } catch (e) {
      print("Error redeeming invite code: $e");
      rethrow;
    }
  }

  Future<void> connectUsers(int idA, int idB,
      {String? sharedCardByPresenter, String? sharedCardByScanner}) async {
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
      print(
          "Successfully connected user $id1 and user $id2 (shares: $u1Share, $u2Share)");
      notifyListeners();
    } catch (e) {
      print("Error connecting users: $e");
      rethrow;
    }
  }

  Future<void> updateConnectionAccess(
      int otherUserId, String newAccessType) async {
    final myUserId = userId;
    if (myUserId == -1) return;

    final int id1 = myUserId < otherUserId ? myUserId : otherUserId;
    final int id2 = myUserId > otherUserId ? myUserId : otherUserId;

    final String columnToUpdate =
        myUserId < otherUserId ? 'user_1_shared_card' : 'user_2_shared_card';

    try {
      await Supabase.instance.client
          .from('user_connections')
          .update({columnToUpdate: newAccessType})
          .eq('user_id_1', id1)
          .eq('user_id_2', id2);
      print(
          "Updated connection access: $myUserId shares $newAccessType with $otherUserId");
      await fetchConnections();
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
          'showProfileToConnections':
              response['show_profile_to_connections'] == true,
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
    gender = '';
    showProfileToConnections = true;
    isCreated = false;
    userId = -1;
    UserData = {};
  }

  // --- Messaging and Chat Room properties & methods ---
  Map<int, String> connectionRooms = {};
  String? activeRoomId;
  List<Map<String, dynamic>> activeRoomMessages = [];
  final Map<String, RealtimeChannel> _roomSubscriptions = {};
  bool isChatRoomsLoaded = false;

  Future<void> loadChatRooms() async {
    final myUserId = userId;
    if (myUserId == -1) return;

    try {
      // 1. Get all room IDs myUserId belongs to
      final myRoomsResponse = await Supabase.instance.client
          .from('room_participants')
          .select('room_id')
          .eq('user_id', myUserId);

      final List<String> myRoomIds =
          (myRoomsResponse as List).map((r) => r['room_id'] as String).toList();

      connectionRooms.clear();

      if (myRoomIds.isNotEmpty) {
        // 2. Fetch all participants of type 'direct' for those rooms
        final participantsResponse = await Supabase.instance.client
            .from('room_participants')
            .select('room_id, user_id, chat_rooms!inner(type)')
            .eq('chat_rooms.type', 'direct')
            .filter('room_id', 'in', '(${myRoomIds.join(",")})');

        for (final row in participantsResponse as List) {
          final int uId = row['user_id'] as int;
          final String rId = row['room_id'] as String;
          if (uId != myUserId) {
            connectionRooms[uId] = rId;
            // Subscribe to this room
            subscribeToRoom(rId);
          }
        }
      }

      isChatRoomsLoaded = true;
      notifyListeners();

      // Fetch any pending messages on app launch
      await fetchPendingMessages();

      // Reconcile statuses of messages WE sent — handles the case where
      // the recipient read our message while we were offline.
      await syncOutgoingMessageStatuses();
      // Reconcile incoming messages that were read elsewhere/deleted from Supabase
      await syncIncomingMessageStatuses();
      await updateUnreadCount();
    } catch (e) {
      print("Error loading chat rooms: $e");
    }
  }

  Future<String> getOrCreateDirectRoom(int otherUserId) async {
    final myUserId = userId;
    if (myUserId == -1) throw Exception("User not authenticated");

    // Check memory cache first
    if (connectionRooms.containsKey(otherUserId)) {
      final roomId = connectionRooms[otherUserId]!;
      subscribeToRoom(roomId);
      return roomId;
    }

    try {
      // 1. Fetch all room IDs that myUserId is in
      final myRoomsResponse = await Supabase.instance.client
          .from('room_participants')
          .select('room_id')
          .eq('user_id', myUserId);

      final List<String> myRoomIds =
          (myRoomsResponse as List).map((r) => r['room_id'] as String).toList();

      if (myRoomIds.isNotEmpty) {
        // 2. See if otherUserId is in any of these rooms, and check if it's a direct room
        final commonResponse = await Supabase.instance.client
            .from('room_participants')
            .select('room_id, chat_rooms!inner(type)')
            .eq('user_id', otherUserId)
            .eq('chat_rooms.type', 'direct')
            .filter('room_id', 'in', '(${myRoomIds.join(",")})')
            .maybeSingle();

        if (commonResponse != null) {
          final roomId = commonResponse['room_id'] as String;
          connectionRooms[otherUserId] = roomId;
          subscribeToRoom(roomId);
          notifyListeners();
          return roomId;
        }
      }

      // 3. Create a new direct room if none exists
      final newRoom = await Supabase.instance.client
          .from('chat_rooms')
          .insert({'type': 'direct'})
          .select('id')
          .single();

      final roomId = newRoom['id'] as String;

      // 4. Add both participants in room_participants
      await Supabase.instance.client.from('room_participants').insert([
        {'room_id': roomId, 'user_id': myUserId},
        {'room_id': roomId, 'user_id': otherUserId},
      ]);

      connectionRooms[otherUserId] = roomId;
      subscribeToRoom(roomId);
      notifyListeners();
      return roomId;
    } catch (e) {
      print("Error in getOrCreateDirectRoom: $e");
      rethrow;
    }
  }

  Future<void> sendChatMessage({
    required String roomId,
    required String text,
    String? replyToMessageId,
    String? replyToMessagePayload,
    String? replyToMessageSenderName,
  }) async {
    final myUserId = userId;
    if (myUserId == -1) return;

    final messageId = const Uuid().v4();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    // ─── STEP 1: Save locally as 'pending' immediately ───────────────────────
    // User sees the message bubble appear instantly with a clock icon ⏱
    // This is the WhatsApp "optimistic send" — no waiting for the server.
    await LocalDatabaseHelper.instance.insertMessage(
      messageId,
      roomId,
      myUserId,
      text,
      status: 'pending',
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      replyToMessagePayload: replyToMessagePayload,
      replyToMessageSenderName: replyToMessageSenderName,
    );
    if (activeRoomId == roomId) {
      await refreshActiveRoomMessages();
    }

    try {
      // ─── STEP 2: Upload to Supabase ────────────────────────────────────────
      await Supabase.instance.client.from('messages').upsert(
        {
          'id': messageId,
          'room_id': roomId,
          'sender_id': myUserId,
          'payload': text,
          'status': 'sent',
          'created_at': createdAt,
          'updated_at': createdAt,
          'reply_to_message_id': replyToMessageId,
          'reply_to_message_payload': replyToMessagePayload,
          'reply_to_message_sender_name': replyToMessageSenderName,
        },
        onConflict: 'id',
      );

      // ─── STEP 3: Server confirmed — show single grey tick ✓ ───────────────
      await LocalDatabaseHelper.instance.updateMessageStatus(messageId, 'sent');
      if (activeRoomId == roomId) {
        await refreshActiveRoomMessages();
      }
    } catch (e) {
      print("Error sending message: $e");
      // Message stays as 'pending' (clock stays visible).
      // syncOutgoingMessageStatuses will reconcile on next app foreground.
    }
  }

  Future<void> deleteChatMessage(String messageId,
      {required bool deleteForEveryone}) async {
    try {
      // 1. Delete from local SQLite
      await LocalDatabaseHelper.instance.deleteMessage(messageId);

      // 2. If deleteForEveryone, delete from Supabase
      if (deleteForEveryone) {
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('id', messageId);
      }

      // 3. Refresh UI
      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error deleting chat message: $e");
    }
  }

  void subscribeToRoom(String roomId) {
    if (_roomSubscriptions.containsKey(roomId)) return;

    final channel = Supabase.instance.client.channel('room-$roomId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final msg = payload.newRecord;
            final msgId = msg['id'] as String;
            final rId = msg['room_id'] as String;
            final senderId = msg['sender_id'] as int;
            final payloadText = msg['payload'] as String;

            // Exclude own messages from processing here since we already stored them on send
            if (senderId == userId) return;

            final bool isInChat = activeRoomId == rId;
            final replyToId = msg['reply_to_message_id'] as String?;
            final replyToPayload = msg['reply_to_message_payload'] as String?;
            final replyToSenderName =
                msg['reply_to_message_sender_name'] as String?;

            // 1. Save to local SQLite
            await LocalDatabaseHelper.instance.insertMessage(
              msgId,
              rId,
              senderId,
              payloadText,
              status: isInChat ? 'read' : 'delivered',
              createdAt: msg['created_at'] as String?,
              replyToMessageId: replyToId,
              replyToMessagePayload: replyToPayload,
              replyToMessageSenderName: replyToSenderName,
            );

            // 2. Acknowledge receipt -> triggers server-side deletion
            await acknowledgeDelivery(msgId, isActiveInChat: isInChat);

            // 3. If actively in chat, update display list; otherwise notify hub list to update snippet
            if (isInChat) {
              await refreshActiveRoomMessages();
            } else {
              notifyListeners();
            }
            await updateUnreadCount();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final newStatus = newRecord['status'] as String;
            final messageId = newRecord['id'] as String;
            final rId = newRecord['room_id'] as String;

            // Update local SQLite status for receipt indicators
            await LocalDatabaseHelper.instance
                .updateMessageStatus(messageId, newStatus);

            if (activeRoomId == rId) {
              await refreshActiveRoomMessages();
            }
            await updateUnreadCount();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final oldRecord = payload.oldRecord;
            final messageId = oldRecord['id'] as String?;
            final rId = oldRecord['room_id'] as String?;

            if (messageId != null) {
              // 1. Cancel notification locally if it exists in the tray
              try {
                await cancelLocalNotification(messageId);
              } catch (e) {
                print("Error cancelling notification in Postgres change listener: $e");
              }

              // 2. Check the local status of the message in our SQLite database.
              // If it wasn't read yet, it means the sender deleted it for everyone.
              final localMsg =
                  await LocalDatabaseHelper.instance.getMessageById(messageId);
              if (localMsg != null) {
                final localStatus = localMsg['status'] as String?;
                if (localStatus != 'read') {
                  // Message was not read locally -> Sender deleted it for everyone!
                  await LocalDatabaseHelper.instance.deleteMessage(messageId);
                } else {
                  // Message was already read -> trigger deleted it. Ensure local is 'read'.
                  await LocalDatabaseHelper.instance
                      .updateMessageStatus(messageId, 'read');
                }
              }

              if (activeRoomId == rId) {
                await refreshActiveRoomMessages();
              }
              await updateUnreadCount();
            }
          },
        )
        .subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await syncOutgoingMessageStatuses();
        await fetchPendingMessages();
        await updateUnreadCount();
      }
    });

    _roomSubscriptions[roomId] = channel;
  }

  Future<void> acknowledgeDelivery(String messageId,
      {bool isActiveInChat = false}) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'status': isActiveInChat ? 'read' : 'delivered'}).eq(
              'id', messageId);
    } catch (e) {
      print("Error acknowledging delivery: $e");
    }
  }

  /// Reconcile outgoing message statuses with Supabase.
  /// Messages sent by us that are no longer in Supabase were read+deleted
  /// by the server trigger — mark them 'read' in local SQLite.
  /// Messages still 'pending' (never reached Supabase) are retried.
  /// Messages still present with a newer status get their local copy updated.
  Future<void> syncOutgoingMessageStatuses() async {
    final myUserId = userId;
    if (myUserId == -1) return;

    try {
      // 1. Get all my sent messages that aren't yet 'read' locally
      final unreadSent =
          await LocalDatabaseHelper.instance.getUnreadSentMessages(myUserId);
      if (unreadSent.isEmpty) return;

      // Separate pending (never reached server) from sent/delivered
      final pendingMsgs =
          unreadSent.where((m) => m['status'] == 'pending').toList();
      final serverMsgs =
          unreadSent.where((m) => m['status'] != 'pending').toList();

      // 2a. Retry pending messages — they never reached Supabase
      for (final msg in pendingMsgs) {
        final msgId = msg['id'] as String;
        final roomId = msg['room_id'] as String;
        try {
          // Fetch full message from SQLite to get payload
          final allMsgs =
              await LocalDatabaseHelper.instance.getMessagesForRoom(roomId);
          final fullMsg = allMsgs.firstWhere(
            (m) => m['id'] == msgId,
            orElse: () => <String, dynamic>{},
          );
          if (fullMsg.isNotEmpty) {
            await Supabase.instance.client.from('messages').upsert(
              {
                'id': msgId,
                'room_id': roomId,
                'sender_id': myUserId,
                'payload': fullMsg['payload'],
                'status': 'sent',
                'created_at': fullMsg['created_at'],
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              onConflict: 'id',
            );
            await LocalDatabaseHelper.instance
                .updateMessageStatus(msgId, 'sent');
          }
        } catch (e) {
          print("Retry failed for pending message $msgId: $e");
          // Will retry next time syncOutgoingMessageStatuses runs
        }
      }

      // 2b. Reconcile sent/delivered messages against Supabase
      if (serverMsgs.isNotEmpty) {
        final messageIds = serverMsgs.map((m) => m['id'] as String).toList();

        final existing = await Supabase.instance.client
            .from('messages')
            .select('id, status')
            .filter('id', 'in', '(${messageIds.join(',')})');

        final Map<String, String> supabaseStatuses = {
          for (final row in existing as List)
            row['id'] as String: row['status'] as String
        };

        // 3. Reconcile
        for (final local in serverMsgs) {
          final msgId = local['id'] as String;
          final localStatus = local['status'] as String;

          if (!supabaseStatuses.containsKey(msgId)) {
            // Row is gone → was read → trigger deleted it
            if (localStatus != 'read') {
              await LocalDatabaseHelper.instance
                  .updateMessageStatus(msgId, 'read');
            }
          } else {
            // Row still exists — adopt the server status if it's "ahead"
            final serverStatus = supabaseStatuses[msgId]!;
            if (_statusRank(serverStatus) > _statusRank(localStatus)) {
              await LocalDatabaseHelper.instance
                  .updateMessageStatus(msgId, serverStatus);
            }
          }
        }
      }

      // 4. Refresh UI if user is in a chat
      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
      await updateUnreadCount();
      // Also sync incoming message statuses to clear any read messages
      await syncIncomingMessageStatuses();
    } catch (e) {
      print("Error syncing outgoing message statuses: $e");
    }
  }

  /// Returns a numeric rank for message statuses for comparison.
  int _statusRank(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'sent':
        return 1;
      case 'delivered':
        return 2;
      case 'read':
        return 3;
      default:
        return -1;
    }
  }

  Future<void> fetchPendingMessages() async {
    final myUserId = userId;
    if (myUserId == -1) return;

    try {
      // Step 1: Get all rooms the user belongs to
      final roomsResponse = await Supabase.instance.client
          .from('room_participants')
          .select('room_id')
          .eq('user_id', myUserId);

      if ((roomsResponse as List).isEmpty) return;

      final roomIds =
          (roomsResponse as List).map((r) => r['room_id'] as String).toList();

      // Step 2: Fetch pending messages (uses store-and-forward sent status)
      final pendingResponse = await Supabase.instance.client
          .from('messages')
          .select()
          .filter('room_id', 'in', '(${roomIds.join(',')})')
          .eq('status', 'sent')
          .neq('sender_id', myUserId);

      // Step 3: Store + acknowledge each message
      for (final msg in pendingResponse as List) {
        final msgId = msg['id'] as String;
        final rId = msg['room_id'] as String;
        final senderId = msg['sender_id'] as int;
        final payloadText = msg['payload'] as String;

        final bool isInChat = activeRoomId == rId;

        await LocalDatabaseHelper.instance.insertMessage(
          msgId,
          rId,
          senderId,
          payloadText,
          status: isInChat ? 'read' : 'delivered',
          createdAt: msg['created_at'] as String?,
          replyToMessageId: msg['reply_to_message_id'] as String?,
          replyToMessagePayload: msg['reply_to_message_payload'] as String?,
          replyToMessageSenderName:
              msg['reply_to_message_sender_name'] as String?,
        );

        await acknowledgeDelivery(msgId, isActiveInChat: isInChat);
      }

      if (activeRoomId != null) {
        await refreshActiveRoomMessages();
      } else {
        notifyListeners();
      }
      await updateUnreadCount();
    } catch (e) {
      print("Error fetching pending messages: $e");
    }
  }

  Future<void> refreshActiveRoomMessages() async {
    if (activeRoomId == null) return;
    activeRoomMessages = List<Map<String, dynamic>>.from(
        await LocalDatabaseHelper.instance.getMessagesForRoom(activeRoomId!));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Called when User B opens a chat room.
  /// Finds any 'delivered' messages in Supabase for this room (rows that
  /// survived the fixed trigger), promotes them to 'read', and updates SQLite.
  /// This is what sends the blue-tick Realtime event to the original sender.
  Future<void> _markDeliveredMessagesAsRead(String roomId) async {
    final myUserId = userId;
    if (myUserId == -1) return;

    try {
      final List<dynamic> deliveredMsgs = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .eq('status', 'delivered')
          .neq('sender_id', myUserId);

      if (deliveredMsgs.isEmpty) return;

      for (final msg in deliveredMsgs) {
        final msgId = msg['id'] as String;
        // Update Supabase → 'read' → trigger deletes row
        //                          → Realtime fires → sender sees blue ticks
        await acknowledgeDelivery(msgId, isActiveInChat: true);
        // Mirror in local SQLite
        await LocalDatabaseHelper.instance.updateMessageStatus(msgId, 'read');
      }

      await refreshActiveRoomMessages();
      await updateUnreadCount();
    } catch (e) {
      print("Error marking delivered messages as read: $e");
    }
  }

  Future<void> updatePushToken(String token) async {
    final myUserId = userId;
    if (myUserId == -1) return;

    try {
      await Supabase.instance.client.from('user_push_tokens').upsert({
        'user_id': myUserId,
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      print("Push token updated successfully in Supabase");
    } catch (e) {
      print("Error updating push token: $e");
    }
  }

  Future<void> markRoomMessagesAsReadLocally(String roomId) async {
    final myUserId = userId;
    if (myUserId == -1) return;
    try {
      final db = await LocalDatabaseHelper.instance.database;
      await db.update(
        'messages',
        {'status': 'read'},
        where: "room_id = ? AND sender_id != ? AND status != 'read'",
        whereArgs: [roomId, myUserId],
      );
    } catch (e) {
      print("Error marking room messages as read locally: $e");
    }
  }

  Future<void> syncIncomingMessageStatuses() async {
    final myUserId = userId;
    if (myUserId == -1) return;

    try {
      // 1. Get all incoming messages that aren't yet 'read' locally
      final db = await LocalDatabaseHelper.instance.database;
      final List<Map<String, dynamic>> unreadIncoming = await db.query(
        'messages',
        columns: ['id'],
        where: "sender_id != ? AND status != 'read'",
        whereArgs: [myUserId],
      );

      if (unreadIncoming.isEmpty) return;

      final messageIds = unreadIncoming.map((m) => m['id'] as String).toList();

      // 2. Query Supabase to see which of these still exist
      final existing = await Supabase.instance.client
          .from('messages')
          .select('id, status')
          .filter('id', 'in', '(${messageIds.join(',')})');

      final Set<String> existingIds = {
        for (final row in existing as List) row['id'] as String
      };

      // 3. If a message is no longer in Supabase, it has been read/deleted.
      // Since unreadIncoming only selects incoming messages (sender_id != myUserId)
      // with status != 'read', any message that is gone from Supabase must have
      // been deleted for everyone by the sender. So we delete it locally!
      for (final localId in messageIds) {
        if (!existingIds.contains(localId)) {
          await LocalDatabaseHelper.instance.deleteMessage(localId);
        }
      }

      // 4. Update the unread count state
      final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM messages WHERE sender_id != ? AND status != 'read'",
        [myUserId],
      );
      if (result.isNotEmpty) {
        totalUnreadCount = Sqflite.firstIntValue(result) ?? 0;
      } else {
        totalUnreadCount = 0;
      }

      // Group by room to update tab counts
      final List<Map<String, dynamic>> roomResults = await db.rawQuery(
        "SELECT room_id, COUNT(*) as count FROM messages WHERE sender_id != ? AND status != 'read' GROUP BY room_id",
        [myUserId],
      );

      final Map<String, int> roomUnreadMap = {
        for (final row in roomResults)
          row['room_id'] as String: int.tryParse(row['count'].toString()) ?? 0
      };

      int casualCount = 0;
      int professionalCount = 0;

      for (final connection in connections) {
        final int connId = connection['id'] as int;
        final String? rId = connectionRooms[connId];
        if (rId != null && roomUnreadMap.containsKey(rId)) {
          final int count = roomUnreadMap[rId]!;
          final sharedCard = (connection['my_shared_card'] ??
                  connection['shared_card'] ??
                  connection['sharedCard'] ??
                  'both')
              .toString()
              .toLowerCase();

          if (sharedCard == 'casual') {
            casualCount += count;
          } else if (sharedCard == 'professional') {
            professionalCount += count;
          } else {
            casualCount += count;
            professionalCount += count;
          }
        }
      }

      casualUnreadCount = casualCount;
      professionalUnreadCount = professionalCount;

      notifyListeners();
    } catch (e) {
      print("Error syncing incoming message statuses: $e");
    }
  }

  void setActiveRoom(String? roomId) {
    activeRoomId = roomId;
    if (roomId != null) {
      // Mark any 'delivered' messages as 'read' now that the user has opened
      // the chat — this fires the blue-tick Realtime event to the sender.
      _markDeliveredMessagesAsRead(roomId);
      // Mark all local messages in SQLite for this room as read immediately
      markRoomMessagesAsReadLocally(roomId).then((_) {
        updateUnreadCount();
      });
      refreshActiveRoomMessages();
    } else {
      activeRoomMessages = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}
