import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'cloudinary_service.dart';
import 'dart:io';
import '../models/recipe_model.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Track view when user opens recipe
  Future<void> trackView(String recipeId) async {
    try {
      await _firestore.collection('recipes').doc(recipeId).update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error tracking view: $e');
    }
  }

  // Get Trending Recipes (based on engagement score and recency)
  Stream<List<RecipeModel>> getTrendingRecipes({int limit = 4}) {
    return _firestore
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final recipes = snapshot.docs
              .map((doc) => RecipeModel.fromFirestore(doc))
              .toList();
          
          final now = DateTime.now();
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          
          // Filter recipes from last 7 days
          var recentRecipes = recipes
              .where((r) => r.createdAt.isAfter(sevenDaysAgo))
              .toList();
          
          // If not enough, extend to last 30 days
          if (recentRecipes.length < limit) {
            final thirtyDaysAgo = now.subtract(const Duration(days: 30));
            recentRecipes = recipes
                .where((r) => r.createdAt.isAfter(thirtyDaysAgo))
                .toList();
          }
          
          // If still not enough, use all recipes
          if (recentRecipes.length < limit) {
            recentRecipes = recipes;
          }
          
          // Sort by engagement score
          recentRecipes.sort((a, b) => 
            b.engagementScore.compareTo(a.engagementScore)
          );
          
          return recentRecipes.take(limit).toList();
        });
  }

  // Get Popular Recipes (based on likes count)
  Stream<List<RecipeModel>> getPopularRecipes({int limit = 6}) {
    return _firestore
        .collection('recipes')
        .orderBy('likesCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecipeModel.fromFirestore(doc))
            .toList());
  }

  // Get Recommended Recipes (based on views count, excluding already shown)
  Stream<List<RecipeModel>> getRecommendedRecipes({
    int limit = 6,
    List<String> excludeIds = const [],
  }) {
      return _firestore
            .collection('recipes')
            .orderBy('viewsCount', descending: true)
            .limit(limit + excludeIds.length + 10)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => RecipeModel.fromFirestore(doc))
                .where((recipe) => !excludeIds.contains(recipe.id))
                .take(limit)
                .toList());
      }

  // Get Popular Creators (based on followers count)
  Future<List<Map<String, dynamic>>> getPopularCreators({int limit = 5}) async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .limit(100)
          .get();
      
      List<Map<String, dynamic>> creatorsWithStats = [];
      
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        
        // Count followers
        final followersSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('followers')
            .count()
            .get();
        
        final followersCount = followersSnapshot.count ?? 0;
        
        // Count recipes
        final recipesSnapshot = await _firestore
            .collection('recipes')
            .where('authorId', isEqualTo: userId)
            .count()
            .get();
        
        final recipesCount = recipesSnapshot.count ?? 0;
        
        // Only include users with recipes or followers
        if (followersCount > 0 || recipesCount > 0) {
          creatorsWithStats.add({
            'userId': userId,
            // Retrieve actual name from Firestore
            'name': userData['name'] ?? 
                   userData['displayName'] ?? 
                   'User',
            // Retrieve actual photo URL from Firestore
            'photoUrl': userData['profileImageUrl'] ?? 
                       userData['photoURL'],
            'followersCount': followersCount,
            'recipesCount': recipesCount,
          });
        }
      }
      
      // Sort by followers count
      creatorsWithStats.sort((a, b) => 
        (b['followersCount'] as int).compareTo(a['followersCount'] as int)
      );
      
      return creatorsWithStats.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting popular creators: $e');
      return [];
    }
  }

  // CREATE Recipe
  Future<String> createRecipe(RecipeModel recipe) async {
    try {
      final docRef = await _firestore.collection('recipes').add(recipe.toFirestore());
      print('Recipe created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating recipe: $e');
      rethrow;
    }
  }

  // READ Single Recipe
  Future<RecipeModel?> getRecipe(String recipeId) async {
    try {
      final doc = await _firestore.collection('recipes').doc(recipeId).get();
      if (!doc.exists) return null;
      return RecipeModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting recipe: $e');
      return null;
    }
  }

  // READ Multiple Recipes with limit
  Stream<List<RecipeModel>> getRecipes({int limit = 20}) {
    return _firestore
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecipeModel.fromFirestore(doc))
            .toList());
  }

  // READ User's Recipes
  Stream<List<RecipeModel>> getUserRecipes(String userId) {
    return _firestore
        .collection('recipes')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecipeModel.fromFirestore(doc))
            .toList());
  }

  // UPDATE Recipe
  Future<void> updateRecipe(String recipeId, RecipeModel recipe) async {
    try {
      await _firestore.collection('recipes').doc(recipeId).update(
            recipe.toFirestore(),
          );
      print('Recipe updated: $recipeId');
    } catch (e) {
      print('Error updating recipe: $e');
      rethrow;
    }
  }

  // DELETE Recipe
  Future<void> deleteRecipe(String recipeId) async {
    try {
      final recipe = await getRecipe(recipeId);
      
      if (recipe != null) {
        if (recipe.coverImageUrl != null) {
          await _deleteImageFromUrl(recipe.coverImageUrl!);
        }
        
        for (var step in recipe.steps) {
          if (step.imageUrl != null) {
            await _deleteImageFromUrl(step.imageUrl!);
          }
        }
      }

      await _firestore.collection('recipes').doc(recipeId).delete();
      print('Recipe deleted: $recipeId');
    } catch (e) {
      print('Error deleting recipe: $e');
      rethrow;
    }
  }

  // SEARCH Recipes
  Stream<List<RecipeModel>> searchRecipes(String query) {
    return _firestore
        .collection('recipes')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecipeModel.fromFirestore(doc))
            .toList());
  }

  // LIKE Recipe
  Future<void> likeRecipe(String recipeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final recipeRef = _firestore.collection('recipes').doc(recipeId);
        final likeRef = _firestore.collection('likes').doc('${userId}_$recipeId');

        final recipeDoc = await transaction.get(recipeRef);
        final likeDoc = await transaction.get(likeRef);

        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(recipeRef, {
            'likesCount': (recipeDoc.data()?['likesCount'] ?? 1) - 1,
          });
        } else {
          transaction.set(likeRef, {
            'userId': userId,
            'recipeId': recipeId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(recipeRef, {
            'likesCount': (recipeDoc.data()?['likesCount'] ?? 0) + 1,
          });
        }
      });
    } catch (e) {
      print('Error liking recipe: $e');
      rethrow;
    }
  }

  // Check if user liked recipe
  Future<bool> isRecipeLiked(String recipeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final doc = await _firestore
          .collection('likes')
          .doc('${userId}_$recipeId')
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // UPLOAD Image
  Future<String> uploadImage(File imageFile, String path) async {
    try {
      final url = await _cloudinaryService.uploadImage(
        imageFile: imageFile,
        folder: path,
      );
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  // DELETE Image from URL
  Future<void> _deleteImageFromUrl(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      if (segments.length < 3) return;

      final publicIdWithExtension = segments.sublist(2).join('/').split('.').first;
      final publicId = publicIdWithExtension;

      final success = await _cloudinaryService.deleteMedia(publicId);
      if (success) {
        print('Image deleted: $publicId');
      } else {
        print('Failed to delete image: $publicId');
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  // Get Recipe Comments
  Stream<List<Comment>> getComments(String recipeId) {
    return _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromFirestore(doc))
            .toList());
  }

  // Add Comment
  Future<void> addComment(String recipeId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('recipes')
          .doc(recipeId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'userPhotoUrl': user.photoURL,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }
}

// Comment Model
class Comment {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}