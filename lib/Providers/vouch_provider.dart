import 'package:flutter/foundation.dart';
import 'package:connect/Models/vouch_model.dart';
import 'package:connect/Repositories/vouch_repository.dart';
import 'package:connect/Repositories/notification_repository.dart';

class VouchProvider with ChangeNotifier {
  final VouchRepository _vouchRepository;

  final Map<int, List<UserVouch>> _vouchesByUser = {};
  final Map<String, bool> _hasVouchedCache = {};
  final Map<String, String> _vouchStatusCache = {};
  final Set<int> _loadingUserIds = {};

  VouchProvider({
    VouchRepository? vouchRepository,
    NotificationRepository? notificationRepository,
  })  : _vouchRepository = vouchRepository ?? SupabaseVouchRepository();

  List<UserVouch> getVouchesFor(int userId) => _vouchesByUser[userId] ?? [];
  bool isLoading(int userId) => _loadingUserIds.contains(userId);

  bool hasVouchedFor(int voucherId, int voucheeId) {
    return _hasVouchedCache['${voucherId}_$voucheeId'] ?? false;
  }

  String? getCachedVouchStatus(int voucherId, int voucheeId) {
    return _vouchStatusCache['${voucherId}_$voucheeId'];
  }

  Future<String?> checkVouchStatus({
    required int voucherId,
    required int voucheeId,
  }) async {
    final key = '${voucherId}_$voucheeId';
    if (_vouchStatusCache.containsKey(key)) {
      return _vouchStatusCache[key];
    }

    final status = await _vouchRepository.getVouchStatusBetween(
      voucherId: voucherId,
      voucheeId: voucheeId,
    );
    if (status != null) {
      _vouchStatusCache[key] = status;
      _hasVouchedCache[key] = true;
    } else {
      _hasVouchedCache[key] = false;
    }
    notifyListeners();
    return status;
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

    final status = await checkVouchStatus(
      voucherId: voucherId,
      voucheeId: voucheeId,
    );
    final hasVouched = status != null;
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
    String? relationshipType,
    List<String>? privateIntents,
    String? optionalNote,
  }) async {
    final vouch = await _vouchRepository.createVouch(
      voucherId: voucherId,
      voucheeId: voucheeId,
      statement: statement,
      feedScope: feedScope,
      announcementPostId: announcementPostId,
      relationshipType: relationshipType,
      privateIntents: privateIntents,
      optionalNote: optionalNote,
    );

    // Update local caches
    final key = '${voucherId}_$voucheeId';
    _hasVouchedCache[key] = true;
    _vouchStatusCache[key] = vouch.status;

    // Only add to profile list if immediately accepted
    if (vouch.status == 'accepted') {
      final currentList = _vouchesByUser[voucheeId] ?? [];
      _vouchesByUser[voucheeId] = [vouch, ...currentList];
    }

    notifyListeners();
    return vouch;
  }

  Future<void> acceptVouch(String vouchId, {int? voucheeId}) async {
    try {
      await _vouchRepository.updateVouchStatus(vouchId: vouchId, status: 'accepted');
      if (voucheeId != null) {
        await loadVouches(voucheeId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error accepting vouch $vouchId: $e");
      rethrow;
    }
  }

  Future<void> declineVouch(String vouchId) async {
    try {
      await _vouchRepository.updateVouchStatus(vouchId: vouchId, status: 'declined');
      notifyListeners();
    } catch (e) {
      debugPrint("Error declining vouch $vouchId: $e");
      rethrow;
    }
  }

  Future<List<String>> getMutualIntents({
    required int userId1,
    required int userId2,
  }) async {
    return _vouchRepository.getMutualIntents(
      userId1: userId1,
      userId2: userId2,
    );
  }

  void clearVouchesBetween(int idA, int idB) {
    _hasVouchedCache.remove('${idA}_$idB');
    _hasVouchedCache.remove('${idB}_$idA');
    _vouchStatusCache.remove('${idA}_$idB');
    _vouchStatusCache.remove('${idB}_$idA');
    _vouchesByUser.remove(idA);
    _vouchesByUser.remove(idB);
    notifyListeners();
  }

  Future<List<String>> deleteVouchesBetween({
    required int userId1,
    required int userId2,
  }) async {
    clearVouchesBetween(userId1, userId2);
    try {
      final deletedPostIds = await _vouchRepository.deleteVouchesBetween(
        userId1: userId1,
        userId2: userId2,
      );
      // Ensure local caches are cleaned for both directions
      _vouchesByUser[userId1]?.removeWhere(
          (v) => v.voucherId == userId2 || v.voucheeId == userId2);
      _vouchesByUser[userId2]?.removeWhere(
          (v) => v.voucherId == userId1 || v.voucheeId == userId1);
      await loadVouches(userId1);
      await loadVouches(userId2);
      notifyListeners();
      return deletedPostIds;
    } catch (e) {
      debugPrint("Error in VouchProvider.deleteVouchesBetween: $e");
      return [];
    }
  }
}
