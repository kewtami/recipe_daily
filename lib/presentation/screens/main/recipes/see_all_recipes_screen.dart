import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recipe_daily/core/models/recipe_model.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../widgets/recipes/recipe_cards.dart';
import 'recipe_detail_screen.dart';

class SeeAllRecipesScreen extends StatelessWidget {
  final String title;
  final List<RecipeModel> recipes;

  const SeeAllRecipesScreen({
    Key? key,
    required this.title,
    required this.recipes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ),
      body: recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No recipes found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                return RecipeCard(
                  recipe: recipes[index],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeDetailScreen(
                          recipeId: recipes[index].id,
                          hideAuthor: recipes[index].authorId ==
                              FirebaseAuth.instance.currentUser?.uid,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}