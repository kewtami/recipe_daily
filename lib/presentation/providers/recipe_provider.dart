import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import '../../core/models/recipe_model.dart';
import '../../core/services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  final RecipeService _recipeService = RecipeService();
  
  List<RecipeModel> _recipes = [];
  List<RecipeModel> _filteredRecipes = [];
  RecipeModel? _currentRecipe;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _recipesSubscription;
  
  // Search and filter state
  String _currentSearchQuery = '';
  Difficulty? _currentDifficulty;
  String? _currentCategory;

  // Getters
  List<RecipeModel> get recipes {
    // If no search/filter, return all recipes
    if (_currentSearchQuery.isEmpty && _currentDifficulty == null && _currentCategory == null) {
      return _recipes;
    }
    // Otherwise, return filtered recipes
    return _filteredRecipes;
  }
  
  // Get original recipes list
  List<RecipeModel> get allRecipes => _recipes;
  
  RecipeModel? get currentRecipe => _currentRecipe;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Clear cache
  void clearCache() {
    _recipes = [];
    _filteredRecipes = [];
    _currentRecipe = null;
    _currentSearchQuery = '';
    _currentDifficulty = null;
    _currentCategory = null;
    _error = null;
    _recipesSubscription?.cancel();
    notifyListeners();
  }

  // CREATE Recipe
  Future<bool> createRecipe({
    required String title,
    required String description,
    required File coverImage,
    required int serves,
    required Duration cookTime,
    required Difficulty difficulty,
    String category = 'Other',
    required List<Ingredient> ingredients,
    required List<RecipeStep> steps,
    required List<String> tags,
    required int totalCalories,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      print('Uploading cover image...');
      final coverImageUrl = await _recipeService.uploadImage(
        coverImage,
        'recipes/covers',
      );

      print('Uploading step images...');
      final List<RecipeStep> stepsWithUrls = [];
      
      for (var step in steps) {
        String? stepImageUrl;
        if (step.imageFile != null) {
          print('Uploading step ${step.stepNumber} image...');
          stepImageUrl = await _recipeService.uploadImage(
            step.imageFile!,
            'recipes/steps',
          );
        }
        
        stepsWithUrls.add(RecipeStep(
          stepNumber: step.stepNumber,
          instruction: step.instruction,
          imageUrl: stepImageUrl,
          timer: step.timer,
        ));
      }

      print('Creating recipe...');
      final recipe = RecipeModel(
        id: '',
        title: title,
        description: description,
        coverImageUrl: coverImageUrl,
        authorId: user.uid,
        authorName: user.displayName ?? 'Anonymous',
        authorPhotoUrl: user.photoURL,
        serves: serves,
        cookTime: cookTime,
        difficulty: difficulty,
        category: category,
        ingredients: ingredients,
        steps: stepsWithUrls,
        tags: tags,
        totalCalories: totalCalories,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final recipeId = await _recipeService.createRecipe(recipe);
      print('Recipe created: $recipeId');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // READ Single Recipe
  Future<void> fetchRecipe(String recipeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentRecipe = await _recipeService.getRecipe(recipeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // READ All Recipes
  void subscribeToRecipes() {
    _isLoading = true;
    notifyListeners();

    _recipesSubscription?.cancel();
    _recipesSubscription = _recipeService.getRecipes().listen(
      (recipes) {
        _recipes = recipes;
        _isLoading = false;
        
        // Reapply current search/filter if any
        if (_currentSearchQuery.isNotEmpty || _currentDifficulty != null || _currentCategory != null) {
          _applySearchAndFilters();
        } else {
          _filteredRecipes = [];
        }
        
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // READ User's Recipes
  void subscribeToUserRecipes(String userId) {
    _isLoading = true;
    notifyListeners();

    _recipesSubscription?.cancel();
    _recipesSubscription = _recipeService.getUserRecipes(userId).listen(
      (recipes) {
        _recipes = recipes;
        _isLoading = false;
        _filteredRecipes = [];
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // UPDATE Recipe
  Future<bool> updateRecipe(String recipeId, RecipeModel recipe) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _recipeService.updateRecipe(recipeId, recipe);
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

  // DELETE Recipe
  Future<bool> deleteRecipe(String recipeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _recipeService.deleteRecipe(recipeId);
      _recipes.removeWhere((recipe) => recipe.id == recipeId);
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

  // LIKE Recipe
  Future<void> toggleLike(String recipeId) async {
    try {
      await _recipeService.likeRecipe(recipeId);
      
      // Update local recipe
      final index = _recipes.indexWhere((r) => r.id == recipeId);
      if (index != -1) {
        // Refresh recipe to get updated like count
        final updatedRecipe = await _recipeService.getRecipe(recipeId);
        if (updatedRecipe != null) {
          _recipes[index] = updatedRecipe;
          notifyListeners();
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Check if recipe is liked
  Future<bool> isRecipeLiked(String recipeId) async {
    return await _recipeService.isRecipeLiked(recipeId);
  }

  // SEARCH Recipes
  void searchRecipes(String query) {
    _currentSearchQuery = query.toLowerCase().trim();
    _applySearchAndFilters();
    notifyListeners();
  }

  // Set filters separately
  void setFilters({Difficulty? difficulty, String? category}) {
    _currentDifficulty = difficulty;
    _currentCategory = category;
    _applySearchAndFilters();
    notifyListeners();
  }

  // Apply search and filters
  void _applySearchAndFilters() {
    // If no search query and no filters, show all recipes
    if (_currentSearchQuery.isEmpty && _currentDifficulty == null && _currentCategory == null) {
      _filteredRecipes = [];
      return;
    }

    _filteredRecipes = _recipes.where((recipe) {
      // Search query matching 
      bool matchesSearch = true;
      if (_currentSearchQuery.isNotEmpty) {
        final titleMatch = recipe.title.toLowerCase().contains(_currentSearchQuery);
        final categoryMatch = recipe.category.toLowerCase().contains(_currentSearchQuery);
        final tagsMatch = recipe.tags.any(
          (tag) => tag.toLowerCase().contains(_currentSearchQuery),
        );
        final descriptionMatch = recipe.description.toLowerCase().contains(_currentSearchQuery);
        
        matchesSearch = titleMatch || categoryMatch || tagsMatch || descriptionMatch;
      }

      // Difficulty filter
      bool matchesDifficulty = true;
      if (_currentDifficulty != null) {
        matchesDifficulty = recipe.difficulty == _currentDifficulty;
      }

      // Category filter
      bool matchesCategory = true;
      if (_currentCategory != null) {
        matchesCategory = recipe.category.toLowerCase() == _currentCategory!.toLowerCase();
      }

      return matchesSearch && matchesDifficulty && matchesCategory;
    }).toList();

    // Sort by relevance only if there's a search query
    if (_currentSearchQuery.isNotEmpty) {
      _filteredRecipes.sort((a, b) {
        final aTitle = a.title.toLowerCase().contains(_currentSearchQuery);
        final bTitle = b.title.toLowerCase().contains(_currentSearchQuery);
        
        if (aTitle && !bTitle) return -1;
        if (!aTitle && bTitle) return 1;
        
        final aCategory = a.category.toLowerCase().contains(_currentSearchQuery);
        final bCategory = b.category.toLowerCase().contains(_currentSearchQuery);
        
        if (aCategory && !bCategory) return -1;
        if (!aCategory && bCategory) return 1;
        
        return 0;
      });
    }
  }

  // Clear search and filters
  void clearSearch() {
    _currentSearchQuery = '';
    _currentDifficulty = null;
    _currentCategory = null;
    _filteredRecipes = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Upload Image (for Edit Recipe)
  Future<String> uploadImage(File imageFile, String path) async {
    try {
      return await _recipeService.uploadImage(imageFile, path);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _recipesSubscription?.cancel();
    super.dispose();
  }
}