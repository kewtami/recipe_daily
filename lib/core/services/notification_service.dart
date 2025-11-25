import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create notification when someone likes a recipe
  static Future<void> createLikeNotification({
    required String recipeId,
    required String recipeOwnerId,
    required String likerUserId,
    required String likerUserName,
    String? likerUserPhoto,
    String? recipeImage,
  }) async {
    // Do not notify if user likes their own recipe
    if (recipeOwnerId == likerUserId) return;

    try {
      await _firestore
          .collection('users')
          .doc(recipeOwnerId)
          .collection('notifications')
          .add({
        'type': 'like',
        'recipeId': recipeId,
        'recipeImage': recipeImage,
        'fromUserId': likerUserId,
        'fromUserName': likerUserName,
        'fromUserPhotoUrl': likerUserPhoto,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating like notification: $e');
    }
  }

  // Create notification when someone comments on a recipe
  static Future<void> createCommentNotification({
    required String recipeId,
    required String recipeOwnerId,
    required String commenterUserId,
    required String commenterUserName,
    String? commenterUserPhoto,
    String? recipeImage,
    required String commentText,
  }) async {
    // Do not notify if user comments on their own recipe
    if (recipeOwnerId == commenterUserId) return;

    try {
      await _firestore
          .collection('users')
          .doc(recipeOwnerId)
          .collection('notifications')
          .add({
        'type': 'comment',
        'recipeId': recipeId,
        'recipeImage': recipeImage,
        'fromUserId': commenterUserId,
        'fromUserName': commenterUserName,
        'fromUserPhotoUrl': commenterUserPhoto,
        'commentText': commentText,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating comment notification: $e');
    }
  }

  // Create notification when someone saves a recipe
  static Future<void> createSaveNotification({
    required String recipeId,
    required String recipeOwnerId,
    required String saverUserId,
    required String saverUserName,
    String? saverUserPhoto,
    String? recipeImage,
  }) async {
    // Do not notify if user saves their own recipe
    if (recipeOwnerId == saverUserId) return;

    try {
      await _firestore
          .collection('users')
          .doc(recipeOwnerId)
          .collection('notifications')
          .add({
        'type': 'save',
        'recipeId': recipeId,
        'recipeImage': recipeImage,
        'fromUserId': saverUserId,
        'fromUserName': saverUserName,
        'fromUserPhotoUrl': saverUserPhoto,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating save notification: $e');
    }
  }

  // Create notification when someone follows a user
  static Future<void> createFollowNotification({
    required String followedUserId,
    required String followerUserId,
    required String followerUserName,
    String? followerUserPhoto,
  }) async {
    // Do not notify if user follows themselves
    if (followedUserId == followerUserId) return;

    try {
      // Check if there's already a recent follow notification (within 24 hours)
      final recentNotif = await _firestore
          .collection('users')
          .doc(followedUserId)
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('fromUserId', isEqualTo: followerUserId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (recentNotif.docs.isNotEmpty) {
        final lastNotif = recentNotif.docs.first;
        final lastNotifTime =
            (lastNotif.data()['createdAt'] as Timestamp?)?.toDate();
        
        if (lastNotifTime != null) {
          final hoursSince = DateTime.now().difference(lastNotifTime).inHours;
          if (hoursSince < 24) {
            // Update existing notification instead of creating new one
            await lastNotif.reference.update({
              'createdAt': FieldValue.serverTimestamp(),
            });
            return;
          }
        }
      }

      // Create new follow notification
      await _firestore
          .collection('users')
          .doc(followedUserId)
          .collection('notifications')
          .add({
        'type': 'follow',
        'fromUserId': followerUserId,
        'fromUserName': followerUserName,
        'fromUserPhotoUrl': followerUserPhoto,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating follow notification: $e');
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      
      final notifications = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  static Future<void> deleteNotification(
    String userId,
    String notificationId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}