import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_daily/presentation/screens/main/recipes/image_viewer_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/recipe_model.dart';
import '../../../providers/recipe_provider.dart';
import '../../../widgets/interactions/like_button.dart';
import '../../../widgets/interactions/save_button.dart';
import '../../../widgets/interactions/comments_section.dart';
import '../../../widgets/recipes/recipe_options_bottom_sheet.dart';
import '../../../widgets/interactions/step_timer.dart';
import '../../../providers/interaction_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  final bool hideAuthor;

  const RecipeDetailScreen({
    Key? key,
    required this.recipeId,
    this.hideAuthor = false,
  }) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int _currentServings = 1;
  bool _isFollowing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
        // Subscribe to realtime updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final interactionProvider = Provider.of<InteractionProvider>(
        context,
        listen: false,
      );
      
      // Subscribe to likes count
      interactionProvider.subscribeToRecipeLikes(widget.recipeId);
      interactionProvider.subscribeToComments(widget.recipeId);
    });
  }

  Future<void> _loadRecipe() async {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    
    try {
      await provider.fetchRecipe(widget.recipeId);
      
      if (provider.currentRecipe != null) {
        setState(() {
          _currentServings = provider.currentRecipe!.serves;
          _loadError = null;
        });
      } else {
        setState(() {
          _loadError = 'Recipe not found';
        });
      }
    } catch (e) {
      String errorMsg = 'Failed to load recipe';
      
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMsg = 'Network error. Check your connection';
      } else if (e.toString().contains('permission') || e.toString().contains('denied')) {
        errorMsg = 'Access denied';
      }
      
      setState(() {
        _loadError = errorMsg;
      });
    }
  }

  void _adjustServings(int change) {
    setState(() {
      _currentServings = (_currentServings + change).clamp(1, 20);
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<RecipeProvider>(
        builder: (context, provider, _) {
          // Loading state
          if (provider.isLoading && _loadError == null) {
            return _buildLoadingState();
          }

          // Error state
          if (_loadError != null || provider.currentRecipe == null) {
            return _buildErrorState(_loadError ?? 'Recipe not found');
          }

          final recipe = provider.currentRecipe!;

          return CustomScrollView(
            slivers: [
              // Cover Image with AppBar
              _buildCoverImage(recipe),
              
              // Recipe Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Difficulty
                      _buildHeader(recipe),
                      const SizedBox(height: 16),
                      
                      // Stats Row
                      _buildStatsRow(recipe),
                      const SizedBox(height: 16),

                      // Author Info
                      _buildAuthorInfo(recipe),
                      const SizedBox(height: 24),
                      
                      // Description
                      _buildDescription(recipe),
                      const SizedBox(height: 32),

                      // Ingredients Section
                      _buildIngredientsSection(recipe),
                      const SizedBox(height: 32),

                      // Steps Section
                      _buildStepsSection(recipe),
                      const SizedBox(height: 32),

                      // Tags Section
                      if (recipe.tags.isNotEmpty) _buildTagsSection(recipe),
                      if (recipe.tags.isNotEmpty) const SizedBox(height: 32),

                      // Author Card
                      if (!widget.hideAuthor) _buildAuthorCard(recipe),
                      const SizedBox(height: 32),

                      // Comments Section
                      CommentsSection(recipeId: widget.recipeId),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Loading recipe...',
              style: TextStyle(
                fontSize: 16, 
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                errorMessage.contains('network') || errorMessage.contains('connection')
                    ? Icons.wifi_off
                    : Icons.restaurant_menu,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                errorMessage.contains('network') || errorMessage.contains('connection')
                    ? 'Connection Error'
                    : 'Recipe Not Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage.contains('network') || errorMessage.contains('connection')
                    ? 'Please check your internet connection\nand try again.'
                    : 'This recipe may have been deleted\nor is no longer available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (errorMessage.contains('network') || errorMessage.contains('connection'))
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadError = null;
                        });
                        _loadRecipe();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24, 
                          vertical: 12,
                        ),
                      ),
                    ),
                  if (errorMessage.contains('network') || errorMessage.contains('connection'))
                    const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24, 
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(RecipeModel recipe) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.width,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), 
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: AppColors.secondary, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), 
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.more_horiz, color: AppColors.secondary, size: 20),
          ),
          onPressed: () {
            final user = FirebaseAuth.instance.currentUser;
            final isOwner = user?.uid == recipe.authorId;
            
            RecipeOptionsBottomSheet.show(
              context: context,
              recipe: recipe,
              mode: isOwner ? 'owner' : 'viewer',
              onEdited: () => _loadRecipe(),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (recipe.coverImageUrl != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(
                        imageUrl: recipe.coverImageUrl!,
                      ),
                    ),
                  );
                },
                child: Image.network(
                  recipe.coverImageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image, 
                            size: 64, 
                            color: Colors.grey[500],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image failed to load',
                            style: TextStyle(
                              color: Colors.grey[600], 
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 64),
              ),
            
            // Save Button
            Positioned(
              bottom: 20,
              right: 20,
              child: SaveButton(
                recipeId: recipe.id,
                iconSize: 24,
                useContainer: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(RecipeModel recipe) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            recipe.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.restaurant_menu, 
            color: AppColors.primary, 
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(RecipeModel recipe) {
    return Row(
      children: [
        // Difficulty
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            recipe.difficulty.displayName,
            style: const TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Cook Time
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              _formatDuration(recipe.cookTime),
              style: TextStyle(
                fontSize: 14, 
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const Spacer(),

        // Likes
        LikeButton(
          recipeId: recipe.id,
          likesCount: recipe.likesCount,
          showCount: true,
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildAuthorInfo(RecipeModel recipe) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: recipe.authorPhotoUrl != null
              ? NetworkImage(recipe.authorPhotoUrl!)
              : null,
          child: recipe.authorPhotoUrl == null
              ? Text(
                  recipe.authorName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          recipe.authorName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(RecipeModel recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recipe.description,
          style: TextStyle(
            fontSize: 15, 
            color: Colors.grey[700], 
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection(RecipeModel recipe) {
    final scaledIngredients = recipe.getScaledIngredients(_currentServings);
    final scaledCalories = recipe.getScaledCalories(_currentServings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ingredients for',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const Spacer(),

            // Serving Adjuster
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: _currentServings > 1 ? () => _adjustServings(-1) : null,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_currentServings',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => _adjustServings(1),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$_currentServings servings',
          style: TextStyle(
            fontSize: 14, 
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        
        // Ingredients List
        ...scaledIngredients.map((ingredient) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15, 
                        color: Colors.grey[800], 
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: '${ingredient.quantity}${ingredient.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' - ${ingredient.name}'),
                        TextSpan(
                          text: ' (${ingredient.method.displayName})',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        TextSpan(
                          text: ' - ${ingredient.calories} kcal',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        const SizedBox(height: 16),

        // Total Calories
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'TOTAL CALORIES: $scaledCalories kcal',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsSection(RecipeModel recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Steps',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 16),
        
        ...recipe.steps.map((step) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Number
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${step.stepNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Step Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.instruction,
                        style: TextStyle(
                          fontSize: 15, 
                          color: Colors.grey[800], 
                          height: 1.5,
                        ),
                      ),

                      // Step Image
                      if (step.imageUrl != null) ...[
                        const SizedBox(height: 12),
                        AspectRatio(
                          aspectRatio:  4/3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImageViewerScreen(
                                      imageUrl: step.imageUrl!,
                                    ),
                                  ),
                                );
                              },
                              child: Image.network(
                                step.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image, 
                                          size: 48, 
                                          color: Colors.grey[500],
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Image unavailable',
                                          style: TextStyle(
                                            color: Colors.grey[600], 
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        
                      ],
                      
                      // Step Timer
                      if (step.timer != null) ...[
                        const SizedBox(height: 12),
                        StepTimer(
                          duration: step.timer!,
                          autoStart: false, // User can start manually
                          onTimerComplete: () {
                            // Handle timer completion (e.g., show a notification)
                            print('Step ${step.stepNumber} timer completed!');
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTagsSection(RecipeModel recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_offer, size: 22, color: AppColors.secondary),
            const SizedBox(width: 8),
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recipe.tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAuthorCard(RecipeModel recipe) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: recipe.authorPhotoUrl != null
                ? NetworkImage(recipe.authorPhotoUrl!)
                : null,
            child: recipe.authorPhotoUrl == null
                ? Text(
                    recipe.authorName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(height: 12),

          Text(
            'By',
            style: TextStyle(
              fontSize: 14, 
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),

          Text(
            recipe.authorName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isFollowing = !_isFollowing;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          _isFollowing ? Icons.person_add : Icons.person_remove,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isFollowing
                              ? 'Now following ${recipe.authorName}'
                              : 'Unfollowed ${recipe.authorName}',
                        ),
                      ],
                    ),
                    backgroundColor: _isFollowing ? AppColors.success : Colors.grey[700],
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey[300] : AppColors.primary,
                foregroundColor: _isFollowing ? AppColors.secondary : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}