import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/interaction_models.dart';
import 'notification_service.dart';

class InteractionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ==================== LIKES ====================
  
  // Toggle like on a recipe
  Future<void> toggleLike(
    String recipeId, 
    String userId, {
    String? userName,
    String? userPhotoUrl,
  }) async {
    final likeQuery = await _firestore
        .collection('likes')
        .where('recipeId', isEqualTo: recipeId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (likeQuery.docs.isEmpty) {
      // Add like
      await _firestore.collection('likes').add({
        'recipeId': recipeId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment likes count
      final recipeRef = _firestore.collection('recipes').doc(recipeId);
      final recipeDoc = await recipeRef.get();
      
      if (recipeDoc.exists) {
        final currentCount = (recipeDoc.data()?['likesCount'] as int?) ?? 0;
        await recipeRef.update({
          'likesCount': currentCount + 1,
        });
      }

      // Create notification
      try {
        if (recipeDoc.exists) {
          final data = recipeDoc.data();
          final recipeOwnerId = data?['authorId'] as String?;
          final recipeImage = data?['coverImageUrl'] as String?;
          
          if (recipeOwnerId != null && recipeOwnerId != userId) {
            await NotificationService.createLikeNotification(
              recipeId: recipeId,
              recipeOwnerId: recipeOwnerId,
              likerUserId: userId,
              likerUserName: userName ?? 'Someone',
              likerUserPhoto: userPhotoUrl,
              recipeImage: recipeImage,
            );
          }
        }
      } catch (_) {}
    } else {
      // Remove like
      await _firestore
          .collection('likes')
          .doc(likeQuery.docs.first.id)
          .delete();

      // Decrement likes count
      final recipeRef = _firestore.collection('recipes').doc(recipeId);
      final recipeDoc = await recipeRef.get();
      
      if (recipeDoc.exists) {
        final currentCount = (recipeDoc.data()?['likesCount'] as int?) ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;
        await recipeRef.update({
          'likesCount': newCount,
        });
      }
    }
  }

  // Check if user liked a recipe
  Future<bool> isRecipeLiked(String recipeId, String userId) async {
    final likeQuery = await _firestore
        .collection('likes')
        .where('recipeId', isEqualTo: recipeId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    return likeQuery.docs.isNotEmpty;
  }

  // Get all liked recipe IDs for a user
  Stream<List<String>> getLikedRecipeIds(String userId) {
    return _firestore
        .collection('likes')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['recipeId'] as String)
            .toList());
  }

  // Get likes count realtime
  Stream<int> getRecipeLikesCount(String recipeId) {
    return _firestore
        .collection('recipes')
        .doc(recipeId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0;
          return (snapshot.data()?['likesCount'] as int?) ?? 0;
        });
  }
  
  // ==================== SAVED RECIPES ====================

  // Toggle save on a recipe
  Future<void> toggleSave(
    String recipeId, 
    String userId, {
    String? userName,
    String? userPhotoUrl,
  }) async {
    final userSaveRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_recipes')
        .doc(recipeId);
    
    final userSaveDoc = await userSaveRef.get();

    if (!userSaveDoc.exists) {
      // Add save
      await userSaveRef.set({
        'savedAt': FieldValue.serverTimestamp(),
      });

      // Increment saves count
      await _firestore.collection('recipes').doc(recipeId).update({
        'savesCount': FieldValue.increment(1),
      });

      // Create notification
      try {
        final recipeDoc = await _firestore.collection('recipes').doc(recipeId).get();
        if (recipeDoc.exists) {
          final data = recipeDoc.data();
          final recipeOwnerId = data?['authorId'] as String?;
          final recipeImage = data?['coverImageUrl'] as String?;
          
          if (recipeOwnerId != null && recipeOwnerId != userId) {
            await NotificationService.createSaveNotification(
              recipeId: recipeId,
              recipeOwnerId: recipeOwnerId,
              saverUserId: userId,
              saverUserName: userName ?? 'Someone',
              saverUserPhoto: userPhotoUrl,
              recipeImage: recipeImage,
            );
          }
        }
      } catch (_) {}
    } else {
      // Unsave
      await _unsaveRecipeCompletely(recipeId, userId);

      // Decrement saves count
      await _firestore.collection('recipes').doc(recipeId).update({
        'savesCount': FieldValue.increment(-1),
      });
    }
  }

  // Completely unsave a recipe
  Future<void> _unsaveRecipeCompletely(String recipeId, String userId) async {
    final batch = _firestore.batch();
    
    // Remove from saved_recipes
    final userSaveRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_recipes')
        .doc(recipeId);
    batch.delete(userSaveRef);
    
    // Remove from all collections
    final collectionsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .get();
    
    for (var collectionDoc in collectionsSnapshot.docs) {
      final recipes = (collectionDoc.data()['recipes'] as List?)?.cast<String>() ?? [];
      
      if (recipes.contains(recipeId)) {
        batch.update(collectionDoc.reference, {
          'recipes': FieldValue.arrayRemove([recipeId]),
        });
      }
    }
    
    await batch.commit();
  }

  // Check if user saved a recipe
  Future<bool> isRecipeSaved(String recipeId, String userId) async {
    final userSaveDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_recipes')
        .doc(recipeId)
        .get();

    return userSaveDoc.exists;
  }

  // Get all saved recipe IDs for a user
  Stream<List<String>> getSavedRecipeIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_recipes')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.id) // doc.id is the recipeId
            .toList());
  }
  
  // ==================== COMMENTS ====================
  
  // Add a comment to a recipe
  Future<String> addComment({
    required String recipeId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
  }) async {
    final docRef = await _firestore.collection('comments').add({
      'recipeId': recipeId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    });

    // Increment comments count
    await _firestore.collection('recipes').doc(recipeId).update({
      'commentsCount': FieldValue.increment(1),
    });

    // Create notification
    try {
      final recipeDoc = await _firestore.collection('recipes').doc(recipeId).get();
      if (recipeDoc.exists) {
        final data = recipeDoc.data();
        final recipeOwnerId = data?['authorId'] as String?;
        final recipeImage = data?['coverImageUrl'] as String?;
        
        if (recipeOwnerId != null && recipeOwnerId != userId) {
          await NotificationService.createCommentNotification(
            recipeId: recipeId,
            recipeOwnerId: recipeOwnerId,
            commenterUserId: userId,
            commenterUserName: userName,
            commenterUserPhoto: userPhotoUrl,
            recipeImage: recipeImage,
            commentText: text,
          );
        }
      }
    } catch (_) {}

    return docRef.id;
  }

  // Update a comment
  Future<void> updateComment(String commentId, String newText) async {
    await _firestore.collection('comments').doc(commentId).update({
      'text': newText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    // Get comment to find associated recipe
    final commentDoc = await _firestore.collection('comments').doc(commentId).get();
    if (commentDoc.exists) {
      final recipeId = commentDoc.data()?['recipeId'] as String?;

      // Delete comment
      await _firestore.collection('comments').doc(commentId).delete();

      // Decrement comments count
      if (recipeId != null) {
        await _firestore.collection('recipes').doc(recipeId).update({
          'commentsCount': FieldValue.increment(-1),
        });
      }
    }
  }

  // Get comments for a recipe
  Stream<List<RecipeComment>> getComments(String recipeId) {
    return _firestore
        .collection('comments')
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList());
  }

  // Get comment count for a recipe
  Future<int> getCommentCount(String recipeId) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('recipeId', isEqualTo: recipeId)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }
}