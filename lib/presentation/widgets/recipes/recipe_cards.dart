import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_daily/presentation/widgets/interactions/save_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/recipe_model.dart';
import '../../providers/interaction_provider.dart';

/// Compact recipe card - used in grids and lists
class RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final bool showMoreButton;

  const RecipeCard({
    Key? key,
    required this.recipe,
    required this.onTap,
    this.onMoreTap,
    this.showMoreButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Square Image
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: recipe.coverImageUrl != null
                      ? Image.network(
                          recipe.coverImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                ),
                
                // More options button
                if (showMoreButton && onMoreTap != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onMoreTap,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                
                // Bookmark button
                if (!showMoreButton && user != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: SaveButton(
                      recipeId: recipe.id,
                      iconSize: 20,
                      useContainer: true,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                
                // Duration badge
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(recipe.cookTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Title
          Text(
            recipe.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A8A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 3),
          
          // Stats
          Row(
            children: [
              const Icon(Icons.local_fire_department, size: 11, color: AppColors.secondary),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  '${recipe.totalCalories} Kcal',
                  style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                recipe.difficulty.displayName,
                style: const TextStyle(
                  fontSize: 10, 
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${minutes} mins';
    } else {
      final hours = duration.inHours;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${remainingMinutes}m';
    }
  }
}

/// Detailed trending recipe card - used in trending sections
class TrendingRecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final VoidCallback onTap;

  const TrendingRecipeCard({
    Key? key,
    required this.recipe,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 350, 
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: recipe.authorPhotoUrl != null
                      ? NetworkImage(recipe.authorPhotoUrl!)
                      : null,
                  child: recipe.authorPhotoUrl == null
                      ? Text(
                          recipe.authorName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'By ${recipe.authorName}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Recipe image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: recipe.coverImageUrl != null
                      ? Image.network(
                          recipe.coverImageUrl!,
                          width: 350,
                          height: 300,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 350,
                              height: 300,
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
                              width: 350,
                              height: 300,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 64),
                            );
                          },
                        )
                      : Container(
                          width: 350,
                          height: 300,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 64),
                        ),
                ),
                
                // Likes badge
                if (user != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Consumer<InteractionProvider>(
                      builder: (context, provider, _) {
                        final isLiked = provider.isRecipeLiked(recipe.id);
                        final likesCount = provider.getLikesCount(recipe.id, recipe.likesCount);
                        
                        return GestureDetector(
                          onTap: () async {
                            try {
                              await provider.toggleLike(recipe.id, user.uid);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.favorite_border : Icons.favorite,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(isLiked ? 'Like removed' : 'Recipe liked'),
                                      ],
                                    ),
                                    backgroundColor: isLiked ? Colors.grey[700] : Colors.red,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update like'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: isLiked ? Colors.red : Colors.grey[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$likesCount',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                // Bookmark button
                if (user != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SaveButton(
                        recipeId: recipe.id,
                        iconSize: 20,
                        useContainer: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                
                // Play button
                if (recipe.coverVideoUrl != null)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                
                // Duration
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatDuration(recipe.cookTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Title
            Text(
              recipe.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Stats
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 14,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${recipe.totalCalories} Kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                    recipe.difficulty.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${minutes} mins';
    } else {
      final hours = duration.inHours;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${remainingMinutes}m';
    }
  }
}