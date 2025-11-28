import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/recipe_model.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/interaction_provider.dart';
import '../../screens/main/profile/popular_creators_screen.dart';
import '../../screens/main/profile/user_profile_screen.dart';
import '../../screens/main/recipes/recipe_detail_screen.dart';
import '../../screens/main/recipes/search_screen.dart';
import '../../screens/main/recipes/see_all_recipes_screen.dart';
import '../../../presentation/widgets/recipes/recipe_cards.dart';

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
      
      recipeProvider.clearSearch();
      
      print('Loading home sections...');
      recipeProvider.subscribeToTrendingRecipes();
      recipeProvider.subscribeToPopularRecipes();
      recipeProvider.subscribeToRecommendedRecipes();
      recipeProvider.loadPopularCreators();
      
      if (user != null) {
        print('Subscribing to user interactions...');
        interactionProvider.subscribeToLikedRecipes(user.uid);
        interactionProvider.subscribeToSavedRecipes(user.uid);
      }
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      final thousands = count / 1000;
      if (thousands >= 100) {
        return '${thousands.toStringAsFixed(0)}K';
      }
      return '${thousands.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildMainContent()),
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
        final hasTrending = provider.trendingRecipes.isNotEmpty;
        final hasPopular = provider.popularRecipes.isNotEmpty;
        final hasRecommended = provider.recommendedRecipes.isNotEmpty;
        final hasCreators = provider.popularCreators.isNotEmpty;
        
        final hasAnyContent = hasTrending || hasPopular || hasRecommended || hasCreators;

        // Temporary debug prints
        print('=== HOME SCREEN DEBUG ===');
        print('Trending: ${provider.trendingRecipes.length}');
        print('Popular: ${provider.popularRecipes.length}');
        print('Recommended: ${provider.recommendedRecipes.length}');
        print('Creators: ${provider.popularCreators.length}');
        print('========================');

        if (!hasAnyContent && provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (!hasAnyContent) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No recipes yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to share a recipe!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              
              // TRENDING (4 recipes)
              if (hasTrending) ...[
                _buildSectionHeader(
                  'Trending', 
                  onSeeAll: () => _navigateToSeeAll('Trending', provider.trendingRecipes)
                ),
                const SizedBox(height: 12),
                _buildTrendingSection(provider.trendingRecipes),
                const SizedBox(height: 32),
              ],
              
              // POPULAR (6 recipes)
              if (hasPopular) ...[
                _buildSectionHeader(
                  'Popular Recipes', 
                  onSeeAll: () => _navigateToSeeAll('Popular Recipes', provider.popularRecipes)
                ),
                const SizedBox(height: 12),
                _buildPopularRecipes(provider.popularRecipes),
                const SizedBox(height: 32),
              ],
              
              // RECOMMENDED (6 recipes)
              if (hasRecommended) ...[
                _buildSectionHeader(
                  'Recommend', 
                  onSeeAll: () => _navigateToSeeAll('Recommend', provider.recommendedRecipes)
                ),
                const SizedBox(height: 12),
                _buildRecommendSection(provider.recommendedRecipes),
                const SizedBox(height: 32),
              ],
              
              // LOADING RECOMMENDED
              if (!hasRecommended && (hasTrending || hasPopular)) ...[
                _buildSectionHeader('Recommend', onSeeAll: null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading recommendations...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              // POPULAR CREATORS (5 users)
              if (hasCreators) ...[
                _buildSectionHeader(
                  'Popular Creators', 
                  onSeeAll: () => _navigateToCreators(provider.popularCreators)
                ),
                const SizedBox(height: 12),
                _buildPopularCreators(provider.popularCreators),
                const SizedBox(height: 32),
              ],
              
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
        itemCount: recipes.length,
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
        itemCount: recipes.length,
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

  Widget _buildPopularCreators(List<Map<String, dynamic>> creators) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: creators.length,
        itemBuilder: (context, index) {
          final creator = creators[index];
          final name = creator['name'] as String;
          final photoUrl = creator['photoUrl'] as String?;
          final followersCount = creator['followersCount'] as int;
          
          return GestureDetector(
            onTap: () {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (creator['userId'] != currentUser?.uid) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: creator['userId'] as String,
                      userName: name,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: photoUrl != null 
                            ? NetworkImage(photoUrl) 
                            : null,
                        child: photoUrl == null
                            ? Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (followersCount > 100)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCount(followersCount)} followers',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Navigate to See All Recipes Screen
  void _navigateToSeeAll(String title, List<RecipeModel> recipes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeeAllRecipesScreen(
          title: title,
          recipes: recipes.take(10).toList(),
        ),
      ),
    );
  }

  // Navigate to Popular Creators Screen
  void _navigateToCreators(List<Map<String, dynamic>> creators) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PopularCreatorsScreen(
          creators: creators.take(10).toList(),
        ),
      ),
    );
  }
}