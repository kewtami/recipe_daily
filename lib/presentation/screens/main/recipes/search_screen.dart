import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/recipe_model.dart';
import '../../../providers/recipe_provider.dart';
import '../../../widgets/recipes/recipe_cards.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<String> _searchHistory = [];
  List<String> _predictiveSuggestions = [];
  bool _isLoading = false;
  
  // Filter states
  Difficulty? _selectedDifficulty;
  String? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchFocusNode.requestFocus();
    
    // Listen to text changes for predictive search
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    // Clear search when leaving screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RecipeProvider>(context, listen: false);
      provider.clearSearch();
    });
    
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      // Remove if already exists
      _searchHistory.remove(query);
      // Add to beginning
      _searchHistory.insert(0, query);
      // Keep only last 10 searches
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    });
    
    await _saveSearchHistory();
  }

  Future<void> _clearHistory() async {
    setState(() {
      _searchHistory.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
  }

  Future<void> _removeFromHistory(String query) async {
    setState(() {
      _searchHistory.remove(query);
    });
    await _saveSearchHistory();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _predictiveSuggestions = [];
      });
      // Clear search when text is empty
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      recipeProvider.clearSearch();
      return;
    }

    // Get predictive suggestions from ALL recipes (not filtered)
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    
    // Access the original recipes list directly
    final allRecipes = recipeProvider.allRecipes;
    
    // Generate suggestions based on recipe titles and tags
    final suggestions = <String>{};
    
    for (var recipe in allRecipes) {
      // Match recipe title
      if (recipe.title.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(recipe.title);
      }
      
      // Match tags
      for (var tag in recipe.tags) {
        if (tag.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(tag);
        }
      }
      
      // Match category
      if (recipe.category.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(recipe.category);
      }
    }
    
    // Add from search history if matches
    for (var historyItem in _searchHistory) {
      if (historyItem.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(historyItem);
      }
    }
    
    setState(() {
      _predictiveSuggestions = suggestions.take(8).toList();
    });
    
    // Perform live search as user types
    _performLiveSearch(query);
  }
  
  void _performLiveSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.searchRecipes(query);
    recipeProvider.setFilters(
      difficulty: _selectedDifficulty,
      category: _selectedCategory,
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    _addToHistory(query);
    _searchFocusNode.unfocus();
    
    // Perform search with filters
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.searchRecipes(query);
    recipeProvider.setFilters(
      difficulty: _selectedDifficulty,
      category: _selectedCategory,
    );
    
    setState(() {
      _isLoading = false;
      _predictiveSuggestions = [];
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedDifficulty = null;
      _selectedCategory = null;
    });
    
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    
    if (_searchController.text.isNotEmpty) {
      // Reapply search without filters
      provider.searchRecipes(_searchController.text);
      provider.setFilters(difficulty: null, category: null);
    } else {
      // Just clear filters
      provider.clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _selectedDifficulty != null || _selectedCategory != null;
    final isSearching = _searchController.text.isNotEmpty || hasActiveFilters;

    return WillPopScope(
      onWillPop: () async {
        // Clear search when back button pressed
        final provider = Provider.of<RecipeProvider>(context, listen: false);
        provider.clearSearch();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () {
            // Clear search before going back
            final provider = Provider.of<RecipeProvider>(context, listen: false);
            provider.clearSearch();
            Navigator.pop(context);
          },
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSubmitted: _performSearch,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search recipes...',
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
                          _predictiveSuggestions = [];
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: hasActiveFilters ? AppColors.primary : Colors.grey[600],
            ),
            onPressed: () => _showFilterModal(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : isSearching
              ? _buildSearchResults()
              : _predictiveSuggestions.isNotEmpty
                  ? _buildPredictiveSuggestions()
                  : _buildSearchHistoryAndSuggestions(),
      ),
    );
  }

  Widget _buildSearchHistoryAndSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Filters
          if (_selectedDifficulty != null || _selectedCategory != null) ...[
            Row(
              children: [
                const Text(
                  'Active Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedDifficulty != null)
                  Chip(
                    label: Text(_selectedDifficulty!.displayName),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedDifficulty = null;
                      });
                    },
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  ),
                if (_selectedCategory != null)
                  Chip(
                    label: Text(_selectedCategory!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Search History
          if (_searchHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ..._searchHistory.map((query) {
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(query, style: const TextStyle(fontSize: 16)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => _removeFromHistory(query),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
              );
            }).toList(),
            
            const SizedBox(height: 32),
          ],
          
          // Popular Searches
          const Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Cupcake',
              'Chocolate',
              'Pasta',
              'Salad',
              'Pizza',
              'Dessert',
            ].map((tag) {
              return InkWell(
                onTap: () {
                  _searchController.text = tag;
                  _performSearch(tag);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictiveSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _predictiveSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _predictiveSuggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: AppColors.secondary),
              children: _highlightMatch(suggestion, _searchController.text),
            ),
          ),
          trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
          onTap: () {
            _searchController.text = suggestion;
            _performSearch(suggestion);
          },
        );
      },
    );
  }

  List<TextSpan> _highlightMatch(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    
    if (index == -1) {
      return [TextSpan(text: text)];
    }
    
    return [
      if (index > 0) TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
      if (index + query.length < text.length)
        TextSpan(text: text.substring(index + query.length)),
    ];
  }

  Widget _buildSearchResults() {
    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        final recipes = provider.recipes;
        
        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No recipes found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or filters',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Results count
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    '${recipes.length} ${recipes.length == 1 ? 'recipe' : 'recipes'} found',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Results grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
            ),
          ],
        );
      },
    );
  }

  void _showFilterModal() {
    Difficulty? tempDifficulty = _selectedDifficulty;
    String? tempCategory = _selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
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
                          color: AppColors.secondary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempDifficulty = null;
                            tempCategory = null;
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
                        
                        Wrap(
                          spacing: 8,
                          children: Difficulty.values.map((difficulty) {
                            final isSelected = tempDifficulty == difficulty;
                            return ChoiceChip(
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
                            );
                          }).toList(),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Category
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Dessert',
                            'Main Course',
                            'Appetizer',
                            'Breakfast',
                            'Salad',
                            'Soup',
                            'Snack',
                          ].map((category) {
                            final isSelected = tempCategory == category;
                            return ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  tempCategory = selected ? category : null;
                                });
                              },
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              side: const BorderSide(color: AppColors.primary),
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
                          _selectedCategory = tempCategory;
                        });
                        Navigator.pop(context);
                        
                        // Apply filters
                        final provider = Provider.of<RecipeProvider>(context, listen: false);
                        
                        if (_searchController.text.isNotEmpty) {
                          // If there's search text, perform search with filters
                          _performSearch(_searchController.text);
                        } else if (_selectedDifficulty != null || _selectedCategory != null) {
                          // If only filters selected, show filtered results
                          provider.searchRecipes(''); // Empty search to trigger filter
                          provider.setFilters(
                            difficulty: _selectedDifficulty,
                            category: _selectedCategory,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply Filters',
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
      ),
    );
  }
}