import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../core/models/recipe_model.dart';
import '../../core/services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  final RecipeService _recipeService = RecipeService();
  
  List<RecipeModel> _recipes = [];
  RecipeModel? _currentRecipe;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<RecipeModel> get recipes => _recipes;
  RecipeModel? get currentRecipe => _currentRecipe;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Clear cache
  void clearCache() {
    _recipes = [];
    _currentRecipe = null;
    _error = null;
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
    _recipeService.getRecipes().listen((recipes) {
      _recipes = recipes;
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
  }

  // READ User's Recipes
  void subscribeToUserRecipes(String userId) {
    _recipeService.getUserRecipes(userId).listen((recipes) {
      _recipes = recipes;
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
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
    _recipeService.searchRecipes(query).listen((recipes) {
      _recipes = recipes;
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
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
}