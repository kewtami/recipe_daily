import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/recipe_model.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/interaction_provider.dart';
import '../../widgets/recipes/recipe_cards.dart';
import 'recipes/recipe_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  List<String> _searchHistory = ['Cupcake', 'Ice Cream'];
  List<String> _searchSuggestions = ['Chocolate Cupcake', 'Ice Cream Sundae'];
  
  // Filter states
  Difficulty? _selectedDifficulty;
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final interactionProvider = Provider.of<InteractionProvider>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
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

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    if (query.isNotEmpty) {
      // Update suggestions based on query
      _searchSuggestions = ['Cupcake', 'Cupcake matcha']
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    
    setState(() {
      if (!_searchHistory.contains(query)) {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 5) {
          _searchHistory.removeLast();
        }
      }
      _isSearching = false;
    });
    
    _searchFocusNode.unfocus();
    Provider.of<RecipeProvider>(context, listen: false).searchRecipes(query);
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterModal(),
    );
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

            // Search Results or Main Content
            Expanded(
              child: _isSearching || _searchController.text.isNotEmpty
                  ? _buildSearchContent()
                  : _buildMainContent(),
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
      child: Row(
        children: [
          // Back Button
          if (_isSearching || _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _isSearching = false;
                });
                _searchFocusNode.unfocus();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          
          if (_isSearching || _searchController.text.isNotEmpty)
            const SizedBox(width: 8),
          
          // Search Field
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: _isSearching ? '' : 'Search recipes',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: AppColors.secondary),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // Filter button
          if (!_isSearching && _searchController.text.isEmpty)
            const SizedBox(width: 12),
          
          if (!_isSearching && _searchController.text.isEmpty)
            IconButton(
              icon: Icon(
                Icons.tune,
                color: _selectedDifficulty != null || _selectedTags.isNotEmpty
                    ? AppColors.primary
                    : Colors.grey[600],
              ),
              onPressed: _showFilterModal,
            ),
          
          // Filter button during search with active filters
          if (_searchController.text.isNotEmpty && (_selectedDifficulty != null || _selectedTags.isNotEmpty))
            IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.primary),
              onPressed: _showFilterModal,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_searchController.text.isEmpty) {
      // Show search history and suggestions
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search History
            if (_searchHistory.isNotEmpty) ...[
              ..._searchHistory.map((query) {
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(query, style: const TextStyle(fontSize: 16)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query);
                  },
                );
              }).toList(),
              
              const SizedBox(height: 24),
            ],
            
            // Search Suggestions
            const Text(
              'Suggestions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 12),
            
            ..._searchSuggestions.map((suggestion) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: () {
                    _searchController.text = suggestion;
                    _performSearch(suggestion);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      );
    } else {
      // Show search results
      return Consumer<RecipeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final recipes = provider.recipes;
          
          if (recipes.isEmpty) {
            return const Center(
              child: Text('No recipes found'),
            );
          }

          return GridView.builder(
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
                        hideAuthor: recipes[index].authorId == FirebaseAuth.instance.currentUser?.uid,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }
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

  Widget _buildFilterModal() {
    Difficulty? tempDifficulty = _selectedDifficulty;
    List<String> tempTags = List.from(_selectedTags);

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              //Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    const Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:  AppColors.secondary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempDifficulty = null;
                          tempTags.clear();
                        });
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Difficulty
                      const Text(
                        'Difficulty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: Difficulty.values.map((difficulty) {
                          final isSelected = tempDifficulty == difficulty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ChoiceChip(
                              label: Text(difficulty.displayName),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  tempDifficulty = selected ? difficulty : null;
                                });
                              },
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Apply Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDifficulty = tempDifficulty;
                        _selectedTags = tempTags;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}