import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int recipesCount;
  final int followingCount;
  final int followersCount;
  final int likesCount;

  UserStats({
    required this.recipesCount,
    required this.followingCount,
    required this.followersCount,
    required this.likesCount,
  });

  factory UserStats.empty() {
    return UserStats(
      recipesCount: 0,
      followingCount: 0,
      followersCount: 0,
      likesCount: 0,
    );
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user stats
  Stream<UserStats> getUserStats(String userId) async* {
    try {
      // Get recipes count
      final recipesSnapshot = await _firestore
          .collection('recipes')
          .where('authorId', isEqualTo: userId)
          .count()
          .get();
      final recipesCount = recipesSnapshot.count ?? 0;

      // Get following count
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();
      final followingCount = followingSnapshot.count ?? 0;

      // Get followers count
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();
      final followersCount = followersSnapshot.count ?? 0;

      // Get total likes count (sum of all recipe likes)
      final recipesQuerySnapshot = await _firestore
          .collection('recipes')
          .where('authorId', isEqualTo: userId)
          .get();
      
      int totalLikes = 0;
      for (var doc in recipesQuerySnapshot.docs) {
        final likesCount = doc.data()['likesCount'] as int? ?? 0;
        totalLikes += likesCount;
      }

      yield UserStats(
        recipesCount: recipesCount,
        followingCount: followingCount,
        followersCount: followersCount,
        likesCount: totalLikes,
      );
    } catch (e) {
      print('Error getting user stats: $e');
      yield UserStats.empty();
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Follow/Unfollow user
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final followingRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final followerRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    final followingDoc = await followingRef.get();

    if (followingDoc.exists) {
      // Unfollow
      await followingRef.delete();
      await followerRef.delete();
    } else {
      // Follow
      await followingRef.set({
        'followedAt': FieldValue.serverTimestamp(),
      });
      await followerRef.set({
        'followedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Check if following
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }
}