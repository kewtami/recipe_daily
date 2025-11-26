import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/recipe_model.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/interaction_provider.dart';
import '../../widgets/recipes/recipe_cards.dart';
import 'recipes/recipe_detail_screen.dart';
import 'recipes/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final interactionProvider = Provider.of<InteractionProvider>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      // Clear any lingering search state
      recipeProvider.clearSearch();
      
      // Load recipes
      print('Loading recipes from Firebase...');
      recipeProvider.subscribeToRecipes();
      
      // Subscribe to user interactions
      if (user != null) {
        print('Subscribing to user interactions...');
        interactionProvider.subscribeToLikedRecipes(user.uid);
        interactionProvider.subscribeToSavedRecipes(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Logo
            _buildHeader(),

            // Search Bar
            _buildSearchBar(),

            // Main Content
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/images/logo_text.png',
            height: 50,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'RECIPE DAILY',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                  height: 1.2,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          // Navigate to search screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchScreen(),
            ),
          );
          
          // Clear search state when returning
          if (mounted) {
            final provider = Provider.of<RecipeProvider>(context, listen: false);
            provider.clearSearch();
          }
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.search, color: AppColors.primary),
              ),
              Expanded(
                child: Text(
                  'Search recipes...',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final recipes = provider.recipes;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              
              // Trending Section
              _buildSectionHeader('Trending', onSeeAll: () {}),
              const SizedBox(height: 12),
              _buildTrendingSection(recipes.take(5).toList()),
              
              const SizedBox(height: 32),
              
              // Popular Recipes Section
              _buildSectionHeader('Popular Recipes', onSeeAll: () {}),
              const SizedBox(height: 12),
              _buildPopularRecipes(recipes),
              
              const SizedBox(height: 32),
              
              // Recommend Section
              _buildSectionHeader('Recommend', onSeeAll: () {}),
              const SizedBox(height: 12),
              _buildRecommendSection(recipes),
              
              const SizedBox(height: 32),
              
              // Popular Creators Section
              _buildSectionHeader('Popular Creators', onSeeAll: () {}),
              const SizedBox(height: 12),
              _buildPopularCreators(),
              
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(List<RecipeModel> recipes) {
    return SizedBox(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return TrendingRecipeCard(
            recipe: recipe,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(
                    recipeId: recipe.id,
                    hideAuthor: recipe.authorId == FirebaseAuth.instance.currentUser?.uid,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularRecipes(List<RecipeModel> recipes) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length > 6 ? 6 : recipes.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 200,
              child: RecipeCard(
                recipe: recipes[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(
                        recipeId: recipes[index].id,
                        hideAuthor: recipes[index].authorId == FirebaseAuth.instance.currentUser?.uid,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendSection(List<RecipeModel> recipes) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length > 6 ? 6 : recipes.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 200,
              child: RecipeCard(
                recipe: recipes[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(
                        recipeId: recipes[index].id,
                        hideAuthor: recipes[index].authorId == FirebaseAuth.instance.currentUser?.uid,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularCreators() {
    final creators = [
      {'name': 'Troyan\nSmith', 'image': null},
      {'name': 'James\nWolden', 'image': null},
      {'name': 'Niki\nSamantha', 'image': null},
      {'name': 'Zayn', 'image': null},
      {'name': 'Robe\nAnn', 'image': null},
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: creators.length,
        itemBuilder: (context, index) {
          final creator = creators[index];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    creator['name']!.split('\n')[0][0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  creator['name']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}