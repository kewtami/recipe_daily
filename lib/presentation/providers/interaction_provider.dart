import 'package:flutter/foundation.dart';
import '../../core/services/interaction_service.dart';
import '../../core/models/interaction_models.dart';

class InteractionProvider extends ChangeNotifier {
  final InteractionService _service = InteractionService();

  // Liked recipes cache
  Set<String> _likedRecipeIds = {};
  Set<String> get likedRecipeIds => _likedRecipeIds;

  // Saved recipes cache
  Set<String> _savedRecipeIds = {};
  Set<String> get savedRecipeIds => _savedRecipeIds;

  // Comments cache
  Map<String, List<RecipeComment>> _commentsCache = {};
  
  // Likes count cache
  Map<String, int> _likesCountCache = {};
  
  // Loading states
  bool _isTogglingLike = false;
  bool _isTogglingSave = false;
  bool _isAddingComment = false;

  bool get isTogglingLike => _isTogglingLike;
  bool get isTogglingSave => _isTogglingSave;
  bool get isAddingComment => _isAddingComment;

  // ==================== LIKES ====================

  // Subscribe to user's liked recipes
  void subscribeToLikedRecipes(String userId) {
    _service.getLikedRecipeIds(userId).listen((likedIds) {
      _likedRecipeIds = Set.from(likedIds);
      notifyListeners();
    });
  }

  // Subscribe to recipe likes count
  void subscribeToRecipeLikes(String recipeId) {
    _service.getRecipeLikesCount(recipeId).listen((count) {
      _likesCountCache[recipeId] = count;
      notifyListeners();
    });
  }

  // Check if recipe is liked
  bool isRecipeLiked(String recipeId) {
    return _likedRecipeIds.contains(recipeId);
  }

  // Get likes count
  int getLikesCount(String recipeId, int defaultCount) {
    return _likesCountCache[recipeId] ?? defaultCount;
  }

  // Toggle like on a recipe
  Future<void> toggleLike(String recipeId, String userId) async {
    if (_isTogglingLike) return;

    _isTogglingLike = true;
    
    try {
      // Check current state before toggle
      final isCurrentlyLiked = _likedRecipeIds.contains(recipeId);
      
      // Optimistic update
      if (isCurrentlyLiked) {
        // Currently liked
        _likedRecipeIds.remove(recipeId);
        _likesCountCache[recipeId] = (_likesCountCache[recipeId] ?? 1) - 1;
      } else {
        // Currently not liked
        _likedRecipeIds.add(recipeId);
        _likesCountCache[recipeId] = (_likesCountCache[recipeId] ?? 0) + 1;
      }
      notifyListeners();

      // Actual update
      await _service.toggleLike(recipeId, userId);
    } catch (e) {
      // Revert on error
      final isCurrentlyLiked = !_likedRecipeIds.contains(recipeId); // Opposite of current state
      
      if (isCurrentlyLiked) {
        _likedRecipeIds.add(recipeId);
        _likesCountCache[recipeId] = (_likesCountCache[recipeId] ?? 0) + 1;
      } else {
        _likedRecipeIds.remove(recipeId);
        _likesCountCache[recipeId] = (_likesCountCache[recipeId] ?? 1) - 1;
      }
      notifyListeners();
      rethrow;
    } finally {
      _isTogglingLike = false;
      notifyListeners();
    }
  }

  // ==================== SAVED RECIPES ====================

  // Subscribe to user's saved recipes
  void subscribeToSavedRecipes(String userId) {
    _service.getSavedRecipeIds(userId).listen((savedIds) {
      _savedRecipeIds = Set.from(savedIds);
      notifyListeners();
    });
  }

  // Check if recipe is saved
  bool isRecipeSaved(String recipeId) {
    return _savedRecipeIds.contains(recipeId);
  }

  // Toggle save on a recipe
  Future<void> toggleSave(String recipeId, String userId) async {
    if (_isTogglingSave) return;

    _isTogglingSave = true;

    try {
      // Check current state before toggle
      final isCurrentlySaved = _savedRecipeIds.contains(recipeId);
      
      // Optimistic update
      if (isCurrentlySaved) {
        // Currently saved
        _savedRecipeIds.remove(recipeId);
      } else {
        // Currently not saved
        _savedRecipeIds.add(recipeId);
      }
      notifyListeners();

      // Actual update
      await _service.toggleSave(recipeId, userId);
    } catch (e) {
      // Revert on error
      final isCurrentlySaved = !_savedRecipeIds.contains(recipeId);
      
      if (isCurrentlySaved) {
        _savedRecipeIds.add(recipeId);
      } else {
        _savedRecipeIds.remove(recipeId);
      }
      notifyListeners();
      rethrow;
    } finally {
      _isTogglingSave = false;
      notifyListeners();
    }
  }

  // ==================== COMMENTS ====================
  
  // Subscribe to comments for a recipe
  void subscribeToComments(String recipeId) {
    _service.getComments(recipeId).listen((comments) {
      _commentsCache[recipeId] = comments;
      notifyListeners();
    });
  }

  // Get comments for a recipe
  List<RecipeComment> getComments(String recipeId) {
    return _commentsCache[recipeId] ?? [];
  }

  // Get comment count for a recipe
  int getCommentCount(String recipeId) {
    return _commentsCache[recipeId]?.length ?? 0;
  }

  // Add a comment
  Future<String> addComment({
    required String recipeId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
  }) async {
    if (_isAddingComment) throw Exception('Already adding comment');

    _isAddingComment = true;

    try {
      // Optimistic update
      final tempComment = RecipeComment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        recipeId: recipeId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        text: text,
        createdAt: DateTime.now(),
        updatedAt: null,
      );
      
      final currentComments = _commentsCache[recipeId] ?? [];
      _commentsCache[recipeId] = [...currentComments, tempComment];
      notifyListeners();

      final commentId = await _service.addComment(
        recipeId: recipeId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        text: text,
      );
      
      // Stream auto update with real comment from backend
      return commentId;
    } catch (e) {
      // Revert optimistic update
      final currentComments = _commentsCache[recipeId] ?? [];
      _commentsCache[recipeId] = currentComments
          .where((c) => !c.id.startsWith('temp_'))
          .toList();
      notifyListeners();
      rethrow;
    } finally {
      _isAddingComment = false;
      notifyListeners();
    }
  }

  // Update a comment
  Future<void> updateComment(String commentId, String recipeId, String newText) async {
    // Optimistic update
    final comments = _commentsCache[recipeId];
    if (comments != null) {
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final updatedComment = RecipeComment(
          id: comments[index].id,
          recipeId: comments[index].recipeId,
          userId: comments[index].userId,
          userName: comments[index].userName,
          userPhotoUrl: comments[index].userPhotoUrl,
          text: newText,
          createdAt: comments[index].createdAt,
          updatedAt: DateTime.now(),
        );
        _commentsCache[recipeId] = [
          ...comments.sublist(0, index),
          updatedComment,
          ...comments.sublist(index + 1),
        ];
        notifyListeners();
      }
    }
    
    try {
      await _service.updateComment(commentId, newText);
    } catch (e) {
      // Revert if error
      rethrow;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String recipeId) async {
    // Optimistic delete
    final comments = _commentsCache[recipeId];
    if (comments != null) {
      final originalComments = List<RecipeComment>.from(comments);
      _commentsCache[recipeId] = comments.where((c) => c.id != commentId).toList();
      notifyListeners();
      
      try {
        await _service.deleteComment(commentId);
      } catch (e) {
        // Revert if error
        _commentsCache[recipeId] = originalComments;
        notifyListeners();
        rethrow;
      }
    }
  }

  // Clear cache
  void clearCache() {
    _likedRecipeIds.clear();
    _savedRecipeIds.clear();
    _commentsCache.clear();
    _likesCountCache.clear();
    notifyListeners();
  }
}