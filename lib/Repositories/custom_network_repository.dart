import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Models/custom_network.dart';

abstract class CustomNetworkRepository {
  Future<CustomNetwork> createNetwork({
    required int creatorId,
    required String name,
    String? description,
    required String iconEmoji,
    required String colorHex,
    required bool isPrivate,
    required bool allowAnonymous,
    List<int> initialMemberIds = const [],
  });

  Future<List<CustomNetwork>> getMyNetworks(int userId);

  Future<List<CustomNetworkMember>> getNetworkMembers(String networkId);

  Future<void> addMemberDirectly({
    required String networkId,
    required int userId,
    required int addedBy,
    String? networkName,
    String role = 'member',
  });

  Future<void> addMembersBatch({
    required String networkId,
    required List<int> userIds,
    required int addedBy,
    String? networkName,
  });

  Future<void> removeMember({
    required String networkId,
    required int userId,
  });

  Future<void> updatePinnedPost({
    required String networkId,
    required String? postId,
  });

  Future<CustomNetwork?> getNetworkById(
    String networkId, {
    int? currentUserId,
  });

  RealtimeChannel subscribeToNetworks({
    required int userId,
    required VoidCallback onNetworkChanged,
  });

  void unsubscribeChannel(RealtimeChannel channel);
}

class SupabaseCustomNetworkRepository implements CustomNetworkRepository {
  final SupabaseClient _client;

  SupabaseCustomNetworkRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<CustomNetwork> createNetwork({
    required int creatorId,
    required String name,
    String? description,
    required String iconEmoji,
    required String colorHex,
    required bool isPrivate,
    required bool allowAnonymous,
    List<int> initialMemberIds = const [],
  }) async {
    try {
      // 1. Insert network
      final netRes = await _client.from('custom_networks').insert({
        'creator_id': creatorId,
        'name': name.trim(),
        'description': description?.trim(),
        'icon_emoji': iconEmoji,
        'color_hex': colorHex,
        'is_private': isPrivate,
        'allow_anonymous': allowAnonymous,
      }).select().single();

      final String networkId = netRes['id'].toString();

      // 2. Add creator as creator member
      final List<Map<String, dynamic>> membersToAdd = [
        {
          'network_id': networkId,
          'user_id': creatorId,
          'added_by': creatorId,
          'role': 'creator',
        }
      ];

      // 3. Add any initial members directly (Mafia-style direct add)
      for (final memberId in initialMemberIds) {
        if (memberId != creatorId) {
          membersToAdd.add({
            'network_id': networkId,
            'user_id': memberId,
            'added_by': creatorId,
            'role': 'member',
          });
        }
      }

      await _client.from('custom_network_members').upsert(membersToAdd);

      // Send push notifications to initially added members (just like mafia direct-add)
      final initialAddedUserIds =
          initialMemberIds.where((id) => id != creatorId).toList();
      if (initialAddedUserIds.isNotEmpty) {
        final notifRows = initialAddedUserIds
            .map((id) => {
                  'user_id': id,
                  'other_user_id': creatorId,
                  'type': 'referral',
                  'note': jsonEncode({
                    'network_id': networkId,
                    'network_name': name.trim(),
                    'real_type': 'custom_network_added',
                  }),
                  'is_seen': false,
                })
            .toList();
        try {
          await _client.from('connection_notifications').insert(notifRows);
        } catch (e) {
          debugPrint(
              '[CustomNetworkRepository] Error inserting initial member notifications: $e');
        }
      }

      return CustomNetwork.fromJson(
        Map<String, dynamic>.from(netRes),
        currentUserId: creatorId,
      ).copyWith(
        memberCount: membersToAdd.length,
        isMember: true,
        isCreator: true,
      );
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error creating network: $e');
      rethrow;
    }
  }

  @override
  Future<List<CustomNetwork>> getMyNetworks(int userId) async {
    try {
      // Fetch networks where user is member or creator
      final membershipsRes = await _client
          .from('custom_network_members')
          .select('network_id')
          .eq('user_id', userId);

      final memberNetworkIds = (membershipsRes as List)
          .map((m) => m['network_id'].toString())
          .toSet();

      // Also get networks created by user
      final createdRes = await _client
          .from('custom_networks')
          .select()
          .eq('creator_id', userId);

      final List createdList = createdRes as List;
      for (final row in createdList) {
        memberNetworkIds.add(row['id'].toString());
      }

      if (memberNetworkIds.isEmpty) {
        return [];
      }

      // Fetch network records
      final networksRes = await _client
          .from('custom_networks')
          .select()
          .inFilter('id', memberNetworkIds.toList())
          .order('created_at', ascending: false);

      final List networksList = networksRes as List;

      // Compute member counts
      final List<CustomNetwork> result = [];
      for (final row in networksList) {
        final netMap = Map<String, dynamic>.from(row);
        final netId = netMap['id'].toString();

        final countRes = await _client
            .from('custom_network_members')
            .select('id')
            .eq('network_id', netId);

        final count = (countRes as List).length;

        result.add(
          CustomNetwork.fromJson(netMap, currentUserId: userId).copyWith(
            memberCount: count > 0 ? count : 1,
            isMember: true,
            isCreator: netMap['creator_id'] == userId,
          ),
        );
      }

      return result;
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error getting my networks: $e');
      return [];
    }
  }

  @override
  Future<List<CustomNetworkMember>> getNetworkMembers(String networkId) async {
    try {
      final res = await _client
          .from('custom_network_members')
          .select('*, profiles:user_id(name, avatar_url, profession)')
          .eq('network_id', networkId)
          .order('created_at', ascending: true);

      final List list = res as List;
      return list
          .map((row) => CustomNetworkMember.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error getting members: $e');
      return [];
    }
  }

  @override
  Future<void> addMemberDirectly({
    required String networkId,
    required int userId,
    required int addedBy,
    String? networkName,
    String role = 'member',
  }) async {
    try {
      await _client.from('custom_network_members').upsert({
        'network_id': networkId,
        'user_id': userId,
        'added_by': addedBy,
        'role': role,
      });

      // Send push notification to the added user (just like mafia)
      if (userId != addedBy) {
        String resolvedNetworkName = networkName ?? '';
        if (resolvedNetworkName.isEmpty) {
          final netRow = await _client
              .from('custom_networks')
              .select('name')
              .eq('id', networkId)
              .maybeSingle();
          resolvedNetworkName = netRow?['name']?.toString() ?? 'Network';
        }

        try {
          await _client.from('connection_notifications').insert({
            'user_id': userId,
            'other_user_id': addedBy,
            'type': 'referral',
            'note': jsonEncode({
              'network_id': networkId,
              'network_name': resolvedNetworkName,
              'real_type': 'custom_network_added',
            }),
            'is_seen': false,
          });
        } catch (e) {
          debugPrint(
              '[CustomNetworkRepository] Error sending connection notification: $e');
        }
      }
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error adding member directly: $e');
      rethrow;
    }
  }

  @override
  Future<void> addMembersBatch({
    required String networkId,
    required List<int> userIds,
    required int addedBy,
    String? networkName,
  }) async {
    if (userIds.isEmpty) return;
    try {
      final rows = userIds
          .map((id) => {
                'network_id': networkId,
                'user_id': id,
                'added_by': addedBy,
                'role': 'member',
              })
          .toList();
      await _client.from('custom_network_members').upsert(rows);

      // Send push notification to each added member
      final validUserIds = userIds.where((id) => id != addedBy).toList();
      if (validUserIds.isNotEmpty) {
        String resolvedNetworkName = networkName ?? '';
        if (resolvedNetworkName.isEmpty) {
          final netRow = await _client
              .from('custom_networks')
              .select('name')
              .eq('id', networkId)
              .maybeSingle();
          resolvedNetworkName = netRow?['name']?.toString() ?? 'Network';
        }

        final notifRows = validUserIds
            .map((id) => {
                  'user_id': id,
                  'other_user_id': addedBy,
                  'type': 'referral',
                  'note': jsonEncode({
                    'network_id': networkId,
                    'network_name': resolvedNetworkName,
                    'real_type': 'custom_network_added',
                  }),
                  'is_seen': false,
                })
            .toList();

        try {
          await _client.from('connection_notifications').insert(notifRows);
        } catch (e) {
          debugPrint(
              '[CustomNetworkRepository] Error sending batch member notifications: $e');
        }
      }
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error batch adding members: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeMember({
    required String networkId,
    required int userId,
  }) async {
    try {
      await _client
          .from('custom_network_members')
          .delete()
          .eq('network_id', networkId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error removing member: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePinnedPost({
    required String networkId,
    required String? postId,
  }) async {
    try {
      await _client.from('custom_networks').update({
        'pinned_post_id': postId,
      }).eq('id', networkId);
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error updating pinned post: $e');
      rethrow;
    }
  }

  @override
  Future<CustomNetwork?> getNetworkById(
    String networkId, {
    int? currentUserId,
  }) async {
    try {
      final res = await _client
          .from('custom_networks')
          .select()
          .eq('id', networkId)
          .maybeSingle();
      if (res == null) return null;
      return CustomNetwork.fromJson(
        Map<String, dynamic>.from(res),
        currentUserId: currentUserId,
      );
    } catch (e) {
      debugPrint('[CustomNetworkRepository] Error getting network by id: $e');
      return null;
    }
  }

  @override
  RealtimeChannel subscribeToNetworks({
    required int userId,
    required VoidCallback onNetworkChanged,
  }) {
    final channelName = 'custom_networks_sub_$userId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_network_members',
          callback: (payload) {
            onNetworkChanged();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_networks',
          callback: (payload) {
            onNetworkChanged();
          },
        )
        .subscribe();

    return channel;
  }

  @override
  void unsubscribeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
