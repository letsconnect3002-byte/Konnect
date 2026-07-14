import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/app_error.dart';
import 'package:connect/Repositories/tribe_repository.dart';
import 'package:connect/Repositories/notification_repository.dart';
import 'package:collection/collection.dart';

sealed class TribeState {}
class TribeInitial extends TribeState {}
class TribeLoading extends TribeState {}
class TribeLoaded extends TribeState {}
class TribeError extends TribeState {
  final AppError error;
  TribeError(this.error);
}

class TribeProvider with ChangeNotifier {
  final TribeRepository _repository;
  final NotificationRepository _notificationRepository;

  TribeProvider({
    TribeRepository? tribeRepository,
    NotificationRepository? notificationRepository,
  })  : _repository = tribeRepository ?? SupabaseTribeRepository(),
        _notificationRepository = notificationRepository ?? SupabaseNotificationRepository();

  int? _userId;
  int? get userId => _userId;

  TribeState _state = TribeInitial();
  TribeState get state => _state;

  List<Map<String, dynamic>> _myTribes = [];
  List<Map<String, dynamic>> get myTribes => _myTribes;

  // Cache maps
  final Map<String, List<Map<String, dynamic>>> _tribeMembers = {};
  final Map<String, List<Map<String, dynamic>>> _tribeRoles = {};
  final Map<String, List<Map<String, dynamic>>> _tribeMessages = {};
  final Map<String, List<Map<String, dynamic>>> _tribeActivityLog = {};

  final Map<String, RealtimeChannel> _messagesSubscriptions = {};
  final Map<String, RealtimeChannel> _membersSubscriptions = {};
  final Map<String, RealtimeChannel> _activitySubscriptions = {};

  // Blocked-user cache (populated once, updated on block)
  Set<int> _blockedUserIds = {};
  Set<int> get blockedUserIds => _blockedUserIds;

  String? activeTribeId;

  void setActiveTribe(String? tribeId) {
    activeTribeId = tribeId;
  }

  List<Map<String, dynamic>> getMembers(String tribeId) => _tribeMembers[tribeId] ?? [];
  List<Map<String, dynamic>> getRoles(String tribeId) {
    final list = List<Map<String, dynamic>>.from(_tribeRoles[tribeId] ?? []);
    const order = ['don', 'consigliere', 'underboss', 'capo', 'soldier', 'associate'];
    list.sort((a, b) {
      final slugA = (a['slug']?.toString() ?? '').toLowerCase();
      final slugB = (b['slug']?.toString() ?? '').toLowerCase();
      final idxA = order.indexOf(slugA);
      final idxB = order.indexOf(slugB);

      if (idxA != -1 && idxB != -1) {
        return idxA.compareTo(idxB);
      } else if (idxA != -1) {
        return -1;
      } else if (idxB != -1) {
        return 1;
      } else {
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      }
    });
    return list;
  }
  List<Map<String, dynamic>> getMessages(String tribeId) => _tribeMessages[tribeId] ?? [];
  List<Map<String, dynamic>> getActivityLog(String tribeId) => _tribeActivityLog[tribeId] ?? [];

  void updateUserId(int? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        fetchMyTribes(silent: true);
      } else {
        _unsubscribeAll();
        _myTribes.clear();
        _tribeMembers.clear();
        _tribeRoles.clear();
        _tribeMessages.clear();
        _tribeActivityLog.clear();
        _state = TribeInitial();
        notifyListeners();
      }
    }
  }

  void _setError(Object e) {
    _state = TribeError(AppError.from(e));
    notifyListeners();
  }

  // ── Access Control Checker ──
  bool hasPermission(String tribeId, String permissionKey) {
    if (_userId == null) return false;
    
    // Fallback logic check creator
    final tribe = _myTribes.firstWhere(
      (t) => t['tribe_id'] == tribeId || t['id'] == tribeId,
      orElse: () => <String, dynamic>{},
    );
    final actualTribe = tribe.containsKey('tribe') ? tribe['tribe'] : tribe;
    if (actualTribe != null && actualTribe['creator_id'] == _userId) {
      return true; // Creator always has full access
    }

    final members = _tribeMembers[tribeId] ?? [];
    final myMemberRow = members.firstWhere(
      (m) => m['user_id'] == _userId && m['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    if (myMemberRow.isEmpty) return false;
    final role = myMemberRow['role'];
    if (role == null) return false;
    final roleSlug = role['slug']?.toString() ?? '';

    // Strictly enforce delete_tribe and manage_roles are only allowed for the Boss (don)
    if (permissionKey == 'delete_tribe' || permissionKey == 'manage_roles') {
      return roleSlug == 'don';
    }

    final perms = role['permissions'];
    if (perms == null) return false;
    return perms[permissionKey] == true;
  }

  // ── Fetch My Tribes ──
  Future<void> fetchMyTribes({bool silent = false}) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      if (!silent) {
        _state = TribeLoading();
        notifyListeners();
      }
      final list = await _repository.getMyTribes(myUserId);
      _myTribes = list;
      _state = TribeLoaded();
      notifyListeners();
    } catch (e) {
      print("Error fetching my tribes: $e");
      _setError(e);
    }
  }

  // ── Fetch Detailed Data ──
  Future<void> fetchTribeDetails(String tribeId) async {
    try {
      final roles = await _repository.getTribeRoles(tribeId);
      final members = await _repository.getTribeMembers(tribeId);
      _tribeRoles[tribeId] = roles;
      _tribeMembers[tribeId] = members;
      notifyListeners();
    } catch (e) {
      print("Error fetching details for tribe $tribeId: $e");
    }
  }

  Future<void> fetchTribeMessagesAndLog(String tribeId) async {
    try {
      final msgs = await _repository.getTribeMessages(tribeId);
      final logs = await _repository.getTribeActivityLog(tribeId);
      _tribeMessages[tribeId] = msgs;
      _tribeActivityLog[tribeId] = logs;
      notifyListeners();
    } catch (e) {
      print("Error fetching messages/log for tribe $tribeId: $e");
    }
  }

  // ── Realtime Setup ──
  void subscribeToTribeRealtime(String tribeId) {
    if (_messagesSubscriptions.containsKey(tribeId)) return;

    final msgSub = _repository.subscribeToTribeMessages(tribeId, (payload) async {
      print("Realtime tribe message received: $payload");
      await fetchTribeMessagesAndLog(tribeId);
    });
    _messagesSubscriptions[tribeId] = msgSub;

    final memSub = _repository.subscribeToTribeMembers(tribeId, (payload) async {
      print("Realtime tribe member received: $payload");
      await fetchTribeDetails(tribeId);
      await fetchMyTribes(silent: true);
    });
    _membersSubscriptions[tribeId] = memSub;

    final actSub = _repository.subscribeToTribeActivity(tribeId, (payload) async {
      print("Realtime tribe activity received: $payload");
      await fetchTribeMessagesAndLog(tribeId);
    });
    _activitySubscriptions[tribeId] = actSub;
  }

  void unsubscribeFromTribeRealtime(String tribeId) {
    final msgSub = _messagesSubscriptions.remove(tribeId);
    if (msgSub != null) _repository.removeChannel(msgSub);

    final memSub = _membersSubscriptions.remove(tribeId);
    if (memSub != null) _repository.removeChannel(memSub);

    final actSub = _activitySubscriptions.remove(tribeId);
    if (actSub != null) _repository.removeChannel(actSub);
  }

  void _unsubscribeAll() {
    final tribeIds = _messagesSubscriptions.keys.toList();
    for (final id in tribeIds) {
      unsubscribeFromTribeRealtime(id);
    }
  }

  // ── Create Tribe ──
  Future<Map<String, dynamic>?> createTribe({
    required String name,
    required String description,
    required String visibility,
    required bool requiresApproval,
    int? maxMembers,
    String? avatarUrl,
    String? id,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) return null;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final tribeData = {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'visibility': visibility,
        'requires_approval': requiresApproval,
        'max_members': maxMembers,
        'avatar_url': avatarUrl ?? '',
        'creator_id': myUserId,
        'created_at': nowStr,
        'updated_at': nowStr,
      };

      final rolesSeed = [
        {
          'slug': 'don',
          'name': 'The Don (Boss)',
          'icon': '👑',
          'color': '#FFD700',
          'permissions': {
            'manage_roles': true,
            'delete_tribe': true,
            'manage_members': true,
            'edit_tribe': true,
            'invite_members': true,
            'view_activity_log': true,
            'post_messages': true,
          },
          'is_default': false,
          'created_at': nowStr,
        },
        {
          'slug': 'consigliere',
          'name': 'Consigliere',
          'icon': '📜',
          'color': '#C55BFF',
          'permissions': {
            'manage_roles': false,
            'delete_tribe': false,
            'manage_members': false,
            'edit_tribe': false,
            'invite_members': false,
            'view_activity_log': true,
            'post_messages': false,
          },
          'is_default': false,
          'created_at': nowStr,
        },
        {
          'slug': 'underboss',
          'name': 'Underboss',
          'icon': '🛡️',
          'color': '#5B9AFF',
          'permissions': {
            'manage_roles': false,
            'delete_tribe': false,
            'manage_members': true,
            'edit_tribe': true,
            'invite_members': true,
            'view_activity_log': true,
            'post_messages': true,
          },
          'is_default': false,
          'created_at': nowStr,
        },
        {
          'slug': 'capo',
          'name': 'Caporegime (Capo)',
          'icon': '⚔️',
          'color': '#FF4500',
          'permissions': {
            'manage_roles': false,
            'delete_tribe': false,
            'manage_members': false,
            'edit_tribe': true,
            'invite_members': true,
            'view_activity_log': true,
            'post_messages': true,
          },
          'is_default': false,
          'created_at': nowStr,
        },
        {
          'slug': 'soldier',
          'name': 'Soldier',
          'icon': '👤',
          'color': '#FF5B5B',
          'permissions': {
            'manage_roles': false,
            'delete_tribe': false,
            'manage_members': false,
            'edit_tribe': false,
            'invite_members': true,
            'view_activity_log': true,
            'post_messages': true,
          },
          'is_default': false,
          'created_at': nowStr,
        },
        {
          'slug': 'associate',
          'name': 'Associate',
          'icon': '👤',
          'color': '#808080',
          'permissions': {
            'manage_roles': false,
            'delete_tribe': false,
            'manage_members': false,
            'edit_tribe': false,
            'invite_members': false,
            'view_activity_log': false,
            'post_messages': true,
          },
          'is_default': true,
          'created_at': nowStr,
        }
      ];

      final creatorMemberData = {
        'user_id': myUserId,
        'status': 'active',
        'joined_at': nowStr,
        'created_at': nowStr,
        'updated_at': nowStr,
      };

      final result = await _repository.createTribe(tribeData, rolesSeed, creatorMemberData);
      
      // Log creation activity
      final tribeId = result['id'] as String;
      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'joined',
        'created_at': nowStr,
      };
      await _repository.insertTribeActivityLog(activityLog);

      await fetchMyTribes(silent: true);
      return result;
    } catch (e) {
      print("Error creating tribe: $e");
      _setError(e);
      rethrow;
    }
  }

  // ── Join Flows ──
  Future<void> joinTribeDirectly(String tribeId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final tribe = await _repository.getTribeById(tribeId);
      if (tribe == null) throw Exception("Tribe not found.");

      // Check max members
      final max = tribe['max_members'] as int?;
      if (max != null) {
        final activeCount = await _repository.getActiveMembersCount(tribeId);
        if (activeCount >= max) {
          throw Exception("This tribe is full");
        }
      }

      // Check default role
      final roles = await _repository.getTribeRoles(tribeId);
      final defaultRole = roles.firstWhereOrNull((r) => r['is_default'] == true);
      if (defaultRole == null) throw Exception("No default role found.");

      final nowStr = DateTime.now().toUtc().toIso8601String();
      final existing = await _repository.getTribeMember(tribeId, myUserId);

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'joined',
        'created_at': nowStr,
      };

      if (existing != null) {
        // Update existing row
        final updates = {
          'status': 'active',
          'role_id': defaultRole['id'],
          'joined_at': nowStr,
        };
        await _repository.updateTribeMemberStatus(tribeId, myUserId, updates, activityLog);
      } else {
        // Insert new row
        final memberData = {
          'tribe_id': tribeId,
          'user_id': myUserId,
          'role_id': defaultRole['id'],
          'status': 'active',
          'joined_at': nowStr,
          'created_at': nowStr,
          'updated_at': nowStr,
        };
        await _repository.insertTribeMember(memberData);
        await _repository.insertTribeActivityLog(activityLog);
      }

      await fetchMyTribes(silent: true);
      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error joining tribe: $e");
      rethrow;
    }
  }

  Future<void> requestToJoinTribe(String tribeId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final existing = await _repository.getTribeMember(tribeId, myUserId);

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'requested_to_join',
        'created_at': nowStr,
      };

      if (existing != null) {
        final updates = {
          'status': 'requested',
        };
        await _repository.updateTribeMemberStatus(tribeId, myUserId, updates, activityLog);
      } else {
        final memberData = {
          'tribe_id': tribeId,
          'user_id': myUserId,
          'status': 'requested',
          'created_at': nowStr,
          'updated_at': nowStr,
        };
        await _repository.insertTribeMember(memberData);
        await _repository.insertTribeActivityLog(activityLog);
      }

      // Notify Elder / Creator
      final tribe = await _repository.getTribeById(tribeId);
      if (tribe != null) {
        final creatorId = tribe['creator_id'] as int;
        await _notificationRepository.insertNotification(
          userId: creatorId,
          otherUserId: myUserId,
          type: 'referral',
          note: jsonEncode({'tribe_id': tribeId, 'tribe_name': tribe['name'], 'real_type': 'tribe_request'}),
        );
      }

      await fetchMyTribes(silent: true);
    } catch (e) {
      print("Error requesting to join tribe: $e");
      rethrow;
    }
  }

  Future<void> joinTribeWithInviteCode(String inviteCode) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final tribe = await _repository.getTribeByInviteCode(inviteCode);
      if (tribe == null) throw Exception("Invalid invite code.");

      final tribeId = tribe['id'] as String;
      if (tribe['requires_approval'] == true) {
        await requestToJoinTribe(tribeId);
      } else {
        await joinTribeDirectly(tribeId);
      }
    } catch (e) {
      print("Error joining with invite code: $e");
      rethrow;
    }
  }

  // ── Invite Flows ──
  Future<void> inviteUser(String tribeId, int inviteeId, String roleId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    if (!hasPermission(tribeId, 'manage_members')) {
      throw Exception("You do not have permission to invite members.");
    }

    try {
      final tribe = await _repository.getTribeById(tribeId);
      if (tribe == null) throw Exception("Tribe not found.");

      // Check capacity validation before invitation is sent
      final max = tribe['max_members'] as int?;
      if (max != null) {
        final activeCount = await _repository.getActiveMembersCount(tribeId);
        if (activeCount >= max) {
          throw Exception("This tribe is full");
        }
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();
      final existing = await _repository.getTribeMember(tribeId, inviteeId);

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'invited',
        'created_at': nowStr,
      };

      if (existing != null) {
        final updates = {
          'status': 'invited',
          'invited_by': myUserId,
          'role_id': roleId,
        };
        await _repository.updateTribeMemberStatus(tribeId, inviteeId, updates, activityLog);
      } else {
        final memberData = {
          'tribe_id': tribeId,
          'user_id': inviteeId,
          'role_id': roleId,
          'status': 'invited',
          'invited_by': myUserId,
          'created_at': nowStr,
          'updated_at': nowStr,
        };
        await _repository.insertTribeMember(memberData);
        await _repository.insertTribeActivityLog(activityLog);
      }

      // Notify Invitee
      await _notificationRepository.insertNotification(
        userId: inviteeId,
        otherUserId: myUserId,
        type: 'referral',
        note: jsonEncode({'tribe_id': tribeId, 'tribe_name': tribe['name'], 'real_type': 'tribe_invite'}),
      );

      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error inviting user: $e");
      rethrow;
    }
  }

  // ── Status Approval / Management ──
  Future<void> approveRequest(String tribeId, int requesterId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    if (!hasPermission(tribeId, 'manage_members')) {
      throw Exception("You do not have permission to manage members.");
    }

    try {
      // Enforce max members
      final tribe = await _repository.getTribeById(tribeId);
      if (tribe == null) throw Exception("Tribe not found.");
      final max = tribe['max_members'] as int?;
      if (max != null) {
        final activeCount = await _repository.getActiveMembersCount(tribeId);
        if (activeCount >= max) {
          throw Exception("This tribe is full");
        }
      }

      final roles = await _repository.getTribeRoles(tribeId);
      final defaultRole = roles.firstWhereOrNull((r) => r['is_default'] == true);
      if (defaultRole == null) throw Exception("No default role found.");

      final nowStr = DateTime.now().toUtc().toIso8601String();
      final updates = {
        'status': 'active',
        'role_id': defaultRole['id'],
        'joined_at': nowStr,
      };

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': requesterId,
        'action_type': 'joined',
        'created_at': nowStr,
      };

      await _repository.updateTribeMemberStatus(tribeId, requesterId, updates, activityLog);

      // Notify user they joined
      await _notificationRepository.insertNotification(
        userId: requesterId,
        otherUserId: myUserId,
        type: 'referral',
        note: jsonEncode({'tribe_id': tribeId, 'tribe_name': tribe['name'], 'real_type': 'tribe_approved'}),
      );

      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error approving request: $e");
      rethrow;
    }
  }

  Future<void> declineRequestOrInvite(String tribeId, int targetUserId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final isSelf = myUserId == targetUserId;

      if (!isSelf && !hasPermission(tribeId, 'manage_members')) {
        throw Exception("You do not have permission to manage members.");
      }

      final updates = {
        'status': 'declined',
      };

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'declined_invite',
        'created_at': nowStr,
      };

      await _repository.updateTribeMemberStatus(tribeId, targetUserId, updates, activityLog);
      await fetchTribeDetails(tribeId);
      await fetchMyTribes(silent: true);
    } catch (e) {
      print("Error declining invite: $e");
      rethrow;
    }
  }

  Future<void> removeMember(String tribeId, int memberUserId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    if (!hasPermission(tribeId, 'manage_members')) {
      throw Exception("You do not have permission to remove members.");
    }

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final updates = {
        'status': 'removed',
      };

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'removed',
        'created_at': nowStr,
      };

      await _repository.updateTribeMemberStatus(tribeId, memberUserId, updates, activityLog);
      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error removing member: $e");
      rethrow;
    }
  }

  Future<void> leaveTribe(String tribeId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final members = _tribeMembers[tribeId] ?? await _repository.getTribeMembers(tribeId);
      final activeMembers = members.where((m) => m['status'] == 'active').toList();
      
      final myMember = activeMembers.firstWhereOrNull((m) => m['user_id'] == myUserId);
      if (myMember == null) return;

      final myRole = myMember['role'] as Map<String, dynamic>?;
      final isDon = myRole != null && myRole['slug'] == 'don';

      if (isDon) {
        final otherDons = activeMembers.where((m) {
          final r = m['role'] as Map<String, dynamic>?;
          return m['user_id'] != myUserId && r != null && r['slug'] == 'don';
        }).toList();

        if (otherDons.isEmpty) {
          final otherActive = activeMembers.where((m) => m['user_id'] != myUserId).toList();
          if (otherActive.isNotEmpty) {
            throw Exception("You are the last Don. Designate another Don before leaving.");
          } else {
            // Absolute last member — delete tribe to prevent zombies
            await _repository.deleteTribe(tribeId);
            await fetchMyTribes(silent: true);
            return;
          }
        }
      }

      final updates = {
        'status': 'left',
      };

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'left',
        'created_at': nowStr,
      };

      await _repository.updateTribeMemberStatus(tribeId, myUserId, updates, activityLog);
      await fetchMyTribes(silent: true);
    } catch (e) {
      print("Error leaving tribe: $e");
      rethrow;
    }
  }

  Future<void> changeMemberRole(String tribeId, int memberUserId, String? roleId) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    if (!hasPermission(tribeId, 'manage_roles')) {
      throw Exception("You do not have permission to manage roles.");
    }

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final members = _tribeMembers[tribeId] ?? [];
      final member = members.firstWhereOrNull((m) => m['user_id'] == memberUserId);
      final prevRoleId = member != null ? member['role_id'] : null;

      final updates = {
        'role_id': roleId,
      };

      final activityLog = {
        'tribe_id': tribeId,
        'actor_id': myUserId,
        'action_type': 'role_changed',
        'metadata': {
          'previous_role_id': prevRoleId,
          'new_role_id': roleId,
        },
        'created_at': nowStr,
      };

      await _repository.changeMemberRole(tribeId, memberUserId, roleId, updates, activityLog);
      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error changing member role: $e");
      rethrow;
    }
  }

  // ── Chat Messaging ──
  Future<void> sendTribeTextMessage(String tribeId, String content, {String? replyToId}) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final messageData = {
        'tribe_id': tribeId,
        'sender_id': myUserId,
        'content': content,
        'message_type': 'text',
        'reply_to_message_id': replyToId,
        'is_edited': false,
        'is_deleted': false,
        'created_at': nowStr,
        'updated_at': nowStr,
      };

      final msg = await _repository.insertTribeMessage(messageData);

      // Cache locally
      final currentList = _tribeMessages[tribeId] ?? [];
      _tribeMessages[tribeId] = [...currentList, msg];
      notifyListeners();
    } catch (e) {
      print("Error sending tribe message: $e");
      rethrow;
    }
  }

  Future<void> sendTribeImageMessage(String tribeId, String imageUrl, {String? replyToId}) async {
    final myUserId = _userId;
    if (myUserId == null) return;

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final messageData = {
        'tribe_id': tribeId,
        'sender_id': myUserId,
        'content': '[Image]',
        'message_type': 'image',
        'attachment_url': imageUrl,
        'reply_to_message_id': replyToId,
        'is_edited': false,
        'is_deleted': false,
        'created_at': nowStr,
        'updated_at': nowStr,
      };

      final msg = await _repository.insertTribeMessage(messageData);

      final currentList = _tribeMessages[tribeId] ?? [];
      _tribeMessages[tribeId] = [...currentList, msg];
      notifyListeners();
    } catch (e) {
      print("Error sending tribe image message: $e");
      rethrow;
    }
  }

  Future<void> softDeleteTribeMessage(String tribeId, String messageId) async {
    try {
      await _repository.softDeleteTribeMessage(messageId);
      await fetchTribeMessagesAndLog(tribeId);
    } catch (e) {
      print("Error deleting message: $e");
      rethrow;
    }
  }

  Future<void> updateTribeMessage(String tribeId, String messageId, String newContent) async {
    try {
      await _repository.updateTribeMessage(messageId, newContent);
      await fetchTribeMessagesAndLog(tribeId);
    } catch (e) {
      print("Error updating message: $e");
      rethrow;
    }
  }

  // ── Tribe Management ──
  Future<void> editTribe(String tribeId, Map<String, dynamic> updates) async {
    if (!hasPermission(tribeId, 'edit_tribe')) {
      throw Exception("You do not have permission to edit this tribe.");
    }
    try {
      await _repository.updateTribe(tribeId, updates);
      await fetchMyTribes(silent: true);
    } catch (e) {
      print("Error editing tribe: $e");
      rethrow;
    }
  }

  Future<void> deleteTribe(String tribeId) async {
    if (!hasPermission(tribeId, 'delete_tribe')) {
      throw Exception("You do not have permission to delete this tribe.");
    }
    try {
      unsubscribeFromTribeRealtime(tribeId);
      await _repository.deleteTribe(tribeId);
      await fetchMyTribes(silent: true);
    } catch (e) {
      print("Error deleting tribe: $e");
      rethrow;
    }
  }

  // ── Role Management ──
  Future<void> createCustomRole(
    String tribeId,
    String roleName,
    String icon,
    String color,
    Map<String, bool> permissions,
  ) async {
    if (!hasPermission(tribeId, 'manage_roles')) {
      throw Exception("You do not have permission to manage roles.");
    }
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final slug = roleName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final roleData = {
        'tribe_id': tribeId,
        'slug': slug,
        'name': roleName,
        'icon': icon,
        'color': color,
        'permissions': permissions,
        'is_default': false,
        'created_at': nowStr,
      };
      await _repository.createTribeRole(roleData);
      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error creating custom role: $e");
      rethrow;
    }
  }

  Future<void> updateCustomRole(String tribeId, String roleId, Map<String, dynamic> updates) async {
    if (!hasPermission(tribeId, 'manage_roles')) {
      throw Exception("You do not have permission to manage roles.");
    }
    try {
      await _repository.updateTribeRole(roleId, updates);
      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error updating custom role: $e");
      rethrow;
    }
  }

  Future<void> deleteCustomRole(String tribeId, String roleId) async {
    if (!hasPermission(tribeId, 'manage_roles')) {
      throw Exception("You do not have permission to manage roles.");
    }
    try {
      // Reassign members holding this role to the default role first
      final roles = _tribeRoles[tribeId] ?? await _repository.getTribeRoles(tribeId);
      final defaultRole = roles.firstWhereOrNull((r) => r['is_default'] == true);
      if (defaultRole == null) throw Exception("No default role found to fall back.");

      final members = _tribeMembers[tribeId] ?? await _repository.getTribeMembers(tribeId);
      final affectedMembers = members.where((m) => m['role_id'] == roleId).toList();

      for (final mem in affectedMembers) {
        final memUserId = mem['user_id'] as int;
        await changeMemberRole(tribeId, memUserId, defaultRole['id']);
      }

      await _repository.deleteTribeRole(roleId);
      await fetchTribeDetails(tribeId);
    } catch (e) {
      print("Error deleting custom role: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchPublicTribes(String query) async {
    return _repository.searchPublicTribes(query);
  }

  // ── Moderation ──

  Future<void> fetchBlockedUserIds() async {
    final myUserId = _userId;
    if (myUserId == null) return;
    try {
      _blockedUserIds = await _repository.getBlockedUserIds(myUserId);
      notifyListeners();
    } catch (e) {
      print("Error fetching blocked users: $e");
    }
  }

  Future<void> reportTribeMessage({
    required int reportedUserId,
    String? messageId,
    String? messageContent,
    required String reason,
    String? additionalDetails,
  }) async {
    final myUserId = _userId;
    if (myUserId == null) throw Exception("User not authenticated.");
    await _repository.reportTribeMessage(
      reporterId: myUserId,
      reportedUserId: reportedUserId,
      messageId: messageId,
      messageContent: messageContent,
      reason: reason,
      additionalDetails: additionalDetails,
    );
  }

  Future<void> blockUserInTribe(int blockedUserId) async {
    final myUserId = _userId;
    if (myUserId == null) throw Exception("User not authenticated.");
    await _repository.blockUserInTribe(
      blockerId: myUserId,
      blockedId: blockedUserId,
    );
    _blockedUserIds.add(blockedUserId);
    notifyListeners();
  }
}
