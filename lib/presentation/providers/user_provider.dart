import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class UserStats {
  final int recipesCount;
  final int followersCount;
  final int followingCount;
  final int likesCount;

  UserStats({
    this.recipesCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
  });
}

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User stats
  UserStats _userStats = UserStats();
  UserStats get userStats => _userStats;

  // User profile data
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  // Stream subscriptions
  StreamSubscription? _userStatsSubscription;
  StreamSubscription? _userProfileSubscription;

  // Loading states
  bool _isLoadingStats = false;
  bool _isLoadingProfile = false;

  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingProfile => _isLoadingProfile;

  // Load user profile data
  Future<void> loadUserProfile(String userId) async {
    try {
      _isLoadingProfile = true;
      notifyListeners();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        _userProfile = userDoc.data();
        debugPrint('User profile loaded: ${_userProfile?['displayName']}');
      } else {
        debugPrint('User profile not found');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  // Subscribe to user stats updates
  void subscribeToUserStats(String userId) {
    _userStatsSubscription?.cancel();

    _isLoadingStats = true;
    notifyListeners();

    _userStatsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      (userSnapshot) async {
        if (!userSnapshot.exists) {
          debugPrint('User document not found');
          _isLoadingStats = false;
          notifyListeners();
          return;
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;

        // Count actual recipes
        final recipesSnapshot = await _firestore
            .collection('recipes')
            .where('authorId', isEqualTo: userId)
            .get();
        final recipesCount = recipesSnapshot.docs.length;

        // Count followers
        final followersSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('followers')
            .get();
        final followersCount = followersSnapshot.docs.length;

        // Count following
        final followingSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('following')
            .get();
        final followingCount = followingSnapshot.docs.length;

        // Count likes received (all likes on user's recipes)
        int likesCount = 0;
        if (recipesCount > 0) {
          final recipeIds = recipesSnapshot.docs.map((doc) => doc.id).toList();
          
          // Count likes for each recipe
          for (final recipeId in recipeIds) {
            final likesSnapshot = await _firestore
                .collection('likes')
                .where('recipeId', isEqualTo: recipeId)
                .get();
            likesCount += likesSnapshot.docs.length;
          }
        }

        _userStats = UserStats(
          recipesCount: recipesCount,
          followersCount: followersCount,
          followingCount: followingCount,
          likesCount: likesCount,
        );

        debugPrint('User stats updated:');
        debugPrint('Recipes: $recipesCount');
        debugPrint('Followers: $followersCount');
        debugPrint('Following: $followingCount');
        debugPrint('Likes: $likesCount');

        // Update Firestore counts (for future optimization)
        _firestore.collection('users').doc(userId).update({
          'recipesCount': recipesCount,
          'followersCount': followersCount,
          'followingCount': followingCount,
          'likesReceivedCount': likesCount,
        }).catchError((e) {
          debugPrint('Failed to update counts in Firestore: $e');
        });

        _isLoadingStats = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error in user stats stream: $error');
        _isLoadingStats = false;
        notifyListeners();
      },
    );
  }

  // Update user profile data
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? photoURL,
    String? bio,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (displayName != null) updates['displayName'] = displayName;
      if (photoURL != null) updates['photoURL'] = photoURL;
      if (bio != null) updates['bio'] = bio;
      
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(userId).update(updates);

      // Reload profile
      await loadUserProfile(userId);
      
      debugPrint('User profile updated');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  // Clear user data
  void clearUserData() {
    _userStats = UserStats();
    _userProfile = null;
    _userStatsSubscription?.cancel();
    _userProfileSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _userStatsSubscription?.cancel();
    _userProfileSubscription?.cancel();
    super.dispose();
  }
}