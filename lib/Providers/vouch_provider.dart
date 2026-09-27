import 'package:flutter/foundation.dart';
import 'package:connect/Models/vouch_model.dart';
import 'package:connect/Repositories/vouch_repository.dart';
import 'package:connect/Repositories/notification_repository.dart';

class VouchProvider with ChangeNotifier {
  final VouchRepository _vouchRepository;
  final NotificationRepository _notificationRepository;

  final Map<int, List<UserVouch>> _vouchesByUser = {};
  final Map<String, bool> _hasVouchedCache = {};
  final Set<int> _loadingUserIds = {};

  VouchProvider({
    VouchRepository? vouchRepository,
    NotificationRepository? notificationRepository,
  })  : _vouchRepository = vouchRepository ?? SupabaseVouchRepository(),
        _notificationRepository =
            notificationRepository ?? SupabaseNotificationRepository();

  List<UserVouch> getVouchesFor(int userId) => _vouchesByUser[userId] ?? [];
  bool isLoading(int userId) => _loadingUserIds.contains(userId);

  bool hasVouchedFor(int voucherId, int voucheeId) {
    return _hasVouchedCache['${voucherId}_$voucheeId'] ?? false;
  }

  Future<List<UserVouch>> loadVouches(int voucheeId) async {
    _loadingUserIds.add(voucheeId);
    notifyListeners();

    try {
      final list = await _vouchRepository.getVouchesForUser(voucheeId);
      _vouchesByUser[voucheeId] = list;
      return list;
    } catch (e) {
      debugPrint("Error loading vouches for user $voucheeId: $e");
      return [];
    } finally {
      _loadingUserIds.remove(voucheeId);
      notifyListeners();
    }
  }

  Future<bool> checkHasVouched({
    required int voucherId,
    required int voucheeId,
  }) async {
    final key = '${voucherId}_$voucheeId';
    if (_hasVouchedCache.containsKey(key)) {
      return _hasVouchedCache[key]!;
    }

    final hasVouched = await _vouchRepository.hasUserVouched(
      voucherId: voucherId,
      voucheeId: voucheeId,
    );
    _hasVouchedCache[key] = hasVouched;
    notifyListeners();
    return hasVouched;
  }

  Future<UserVouch> submitVouch({
    required int voucherId,
    required int voucheeId,
    required String statement,
    required String feedScope,
    String? announcementPostId,
  }) async {
    final vouch = await _vouchRepository.createVouch(
      voucherId: voucherId,
      voucheeId: voucheeId,
      statement: statement,
      feedScope: feedScope,
      announcementPostId: announcementPostId,
    );

    // Update local caches
    _hasVouchedCache['${voucherId}_$voucheeId'] = true;
    final currentList = _vouchesByUser[voucheeId] ?? [];
    _vouchesByUser[voucheeId] = [vouch, ...currentList];

    // Send in-app notification to the vouchee
    try {
      await _notificationRepository.insertNotification(
        userId: voucheeId,
        otherUserId: voucherId,
        type: 'vouch',
        note: statement,
      );
    } catch (e) {
      debugPrint("Error inserting vouch notification: $e");
    }

    notifyListeners();
    return vouch;
  }
}
