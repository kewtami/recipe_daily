import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class RecipeModel {
  final String id;
  final String title;
  final String description;
  final String? coverImageUrl;
  final String? coverVideoUrl;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final int serves;
  final Duration cookTime;
  final Difficulty difficulty;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tags;
  final int totalCalories;
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeModel({
    required this.id,
    required this.title,
    required this.description,
    this.coverImageUrl,
    this.coverVideoUrl,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.serves,
    required this.cookTime,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.totalCalories,
    this.likesCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Get scaled ingredients for different servings
  List<Ingredient> getScaledIngredients(int newServings) {
    final scale = newServings / serves;
    return ingredients.map((ing) => ing.scale(scale)).toList();
  }

  // Get scaled total calories for different servings
  int getScaledCalories(int newServings) {
    return (totalCalories * (newServings / serves)).round();
  }

  factory RecipeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RecipeModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      coverImageUrl: data['coverImageUrl'],
      coverVideoUrl: data['coverVideoUrl'],
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'],
      serves: data['serves'] ?? 1,
      cookTime: Duration(seconds: data['cookTimeSeconds'] ?? 0),
      difficulty: Difficulty.values.firstWhere(
        (e) => e.name == data['difficulty'],
        orElse: () => Difficulty.medium,
      ),
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((i) => Ingredient.fromJson(i))
              .toList() ??
          [],
      steps: (data['steps'] as List<dynamic>?)
              ?.map((s) => RecipeStep.fromJson(s))
              .toList() ??
          [],
      tags: List<String>.from(data['tags'] ?? []),
      totalCalories: data['totalCalories'] ?? 0,
      likesCount: data['likesCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'coverVideoUrl': coverVideoUrl,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'serves': serves,
      'cookTimeSeconds': cookTime.inSeconds,
      'difficulty': difficulty.name,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'steps': steps.map((s) => s.toJson()).toList(),
      'tags': tags,
      'totalCalories': totalCalories,
      'likesCount': likesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// Ingredient Model
class Ingredient {
  final double quantity;
  final String unit; // gr, kg, cup, tbsp, etc.
  final String name;
  final CookingMethod method;
  final int calories; // per this quantity

  Ingredient({
    required this.quantity,
    required this.unit,
    required this.name,
    required this.method,
    required this.calories,
  });

  // Scale ingredient by factor
  Ingredient scale(double factor) {
    return Ingredient(
      quantity: quantity * factor,
      unit: unit,
      name: name,
      method: method,
      calories: (calories * factor).round(),
    );
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      name: json['name'] ?? '',
      method: CookingMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => CookingMethod.raw,
      ),
      calories: json['calories'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'unit': unit,
      'name': name,
      'method': method.name,
      'calories': calories,
    };
  }

  String getDisplayText() {
    return '$quantity$unit - $name (${method.displayName}) - $calories kcal';
  }
}

// Recipe Step Model
class RecipeStep {
  final int stepNumber;
  final String instruction;
  final String? imageUrl;
  final Duration? timer;
  final File? imageFile;

  RecipeStep({
    required this.stepNumber,
    required this.instruction,
    this.imageUrl,
    this.timer,
    this.imageFile,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepNumber: json['stepNumber'] ?? 1,
      instruction: json['instruction'] ?? '',
      imageUrl: json['imageUrl'],
      timer: json['timerSeconds'] != null
          ? Duration(seconds: json['timerSeconds'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepNumber': stepNumber,
      'instruction': instruction,
      'imageUrl': imageUrl,
      'timerSeconds': timer?.inSeconds,
    };
  }
}

// Enums
enum Difficulty {
  easy,
  medium,
  hard;

  String get displayName {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }
}

enum CookingMethod {
  raw,
  boiled,
  steamed,
  grilled,
  fried,
  baked,
  roasted,
  sauteed;

  String get displayName {
    switch (this) {
      case CookingMethod.raw:
        return 'Raw';
      case CookingMethod.boiled:
        return 'Boiled';
      case CookingMethod.steamed:
        return 'Steamed';
      case CookingMethod.grilled:
        return 'Grilled';
      case CookingMethod.fried:
        return 'Fried';
      case CookingMethod.baked:
        return 'Baked';
      case CookingMethod.roasted:
        return 'Roasted';
      case CookingMethod.sauteed:
        return 'Sautéed';
    }
  }

  // Calorie multiplier based on cooking method
  double get calorieMultiplier {
    switch (this) {
      case CookingMethod.raw:
        return 1.0;
      case CookingMethod.boiled:
      case CookingMethod.steamed:
        return 1.0;
      case CookingMethod.grilled:
      case CookingMethod.roasted:
        return 1.05;
      case CookingMethod.baked:
        return 1.1;
      case CookingMethod.sauteed:
        return 1.15;
      case CookingMethod.fried:
        return 1.3; // Frying adds significant calories
    }
  }
}