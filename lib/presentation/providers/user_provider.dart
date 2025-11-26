import 'package:flutter/foundation.dart';
import '../../core/services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  
  UserStats _userStats = UserStats.empty();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserStats get userStats => _userStats;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Subscribe to user stats
  void subscribeToUserStats(String userId) {
    _userService.getUserStats(userId).listen((stats) {
      _userStats = stats;
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
  }

  // Load user profile
  Future<void> loadUserProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _userService.getUserProfile(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _userService.updateUserProfile(userId, data);
      _userProfile = {...?_userProfile, ...data};
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear cache
  void clearCache() {
    _userStats = UserStats.empty();
    _userProfile = null;
    _error = null;
    notifyListeners();
  }
}