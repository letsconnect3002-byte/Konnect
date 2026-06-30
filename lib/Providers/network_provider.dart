import 'package:connect/Repositories/network_repository.dart';
import 'package:flutter/material.dart';

class NetworkProvider with ChangeNotifier {
  final NetworkRepository _repository;

  NetworkProvider({NetworkRepository? networkRepository})
      : _repository = networkRepository ?? SupabaseNetworkRepository();

  int _primaryCount = 0;
  int _secondaryCount = 0;
  int _tertiaryCount = 0;

  List<Map<String, dynamic>> _networkList = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _currentPage = 1;
  String _currentSearch = '';
  String _currentSort = 'mutual';

  static const int _pageLimit = 20;

  // Connection change tracking — refreshes network only when the
  // *current* user's connection count actually changes.
  int? _trackedUserId;
  int _lastConnectionCount = -1;
  int _activeLoadSession = 0;

  /// Called by the ProxyProvider whenever ConnectionProvider notifies.
  /// Only triggers a network refresh when the connection count genuinely
  /// changed (i.e., the local user connected/disconnected with someone).
  void updateFromConnectionProvider(int? userId, int connectionCount, bool isLoaded) {
    if (userId == null) return;

    // First time seeing this user — seed tracked user ID, reset count state.
    if (_trackedUserId != userId) {
      _trackedUserId = userId;
      _lastConnectionCount = isLoaded ? connectionCount : -1;
      return;
    }

    // If we're not loaded yet, wait.
    if (!isLoaded) return;

    // If count was not yet seeded (because we weren't loaded when we first saw the user),
    // seed it now and do not refresh yet.
    if (_lastConnectionCount == -1) {
      _lastConnectionCount = connectionCount;
      return;
    }

    // Count hasn't changed — no-op.
    if (connectionCount == _lastConnectionCount) return;

    // Connection count genuinely changed — refresh.
    _lastConnectionCount = connectionCount;
    loadStats(userId);
    loadNetwork(userId, reset: true);
  }

  // Getters
  int get primaryCount => _primaryCount;
  int get secondaryCount => _secondaryCount;
  int get tertiaryCount => _tertiaryCount;

  List<Map<String, dynamic>> get networkList => _networkList;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  int get currentPage => _currentPage;
  String get currentSearch => _currentSearch;
  String get currentSort => _currentSort;

  Future<void> loadStats(int userId) async {
    try {
      final stats = await _repository.getNetworkStats(userId);
      _primaryCount = stats['primary_count'] as int;
      _secondaryCount = stats['secondary_count'] as int;
      _tertiaryCount = stats['tertiary_count'] as int;
      notifyListeners();
    } catch (e) {
      print("Error loading network stats: $e");
    }
  }

  Future<void> loadNetwork(int userId, {bool reset = false}) async {
    if (reset) {
      _activeLoadSession++;
      _currentPage = 1;
      _networkList = [];
      _hasMore = true;
      _isLoading = true;
      notifyListeners();
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    final currentSession = _activeLoadSession;

    try {
      final results = await _repository.getNetworkExpansion(
        userId,
        _currentPage,
        _pageLimit,
        _currentSearch,
        _currentSort,
      );

      if (currentSession != _activeLoadSession) {
        // Discard stale results from a previous concurrent load
        return;
      }

      _networkList.addAll(results);
      _hasMore = results.length >= _pageLimit;
      _currentPage++;
    } catch (e) {
      print("Error loading network expansion: $e");
    } finally {
      if (currentSession == _activeLoadSession) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> search(int userId, String query) async {
    _currentSearch = query;
    await loadNetwork(userId, reset: true);
  }

  Future<void> setSort(int userId, String sort) async {
    _currentSort = sort;
    await loadNetwork(userId, reset: true);
  }
}
