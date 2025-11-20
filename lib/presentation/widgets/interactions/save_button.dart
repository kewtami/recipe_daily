import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/interaction_provider.dart';
import '../../providers/collection_provider.dart';
import '../../../core/constants/app_colors.dart';

class SaveButton extends StatelessWidget {
  final String recipeId;
  final double iconSize;
  final EdgeInsets? padding;
  final bool useContainer;

  const SaveButton({
    Key? key,
    required this.recipeId,
    this.iconSize = 24,
    this.padding,
    this.useContainer = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Consumer<InteractionProvider>(
      builder: (context, provider, _) {
        final isSaved = provider.isRecipeSaved(recipeId);

        Widget iconWidget = Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: isSaved ? AppColors.primary : AppColors.secondary,
          size: iconSize,
        );

        if (useContainer) {
          iconWidget = Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 8,
                ),
              ],
            ),
            child: iconWidget,
          );
        }

        return GestureDetector(
          onTap: () async {
            if (isSaved) {
              // If already saved, just unsave directly
              _handleUnsave(context, user.uid);
            } else {
              // If not saved, show collection selector to save
              _showCollectionSelector(context, user.uid);
            }
          },
          onLongPress: isSaved
              ? () => _showCollectionSelector(context, user.uid)
              : null,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: iconWidget,
          ),
        );
      },
    );
  }

  Future<void> _handleUnsave(BuildContext context, String userId) async {
    try {
      final provider = Provider.of<InteractionProvider>(
        context,
        listen: false,
      );
      await provider.toggleSave(recipeId, userId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.bookmark_border, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Recipe unsaved'),
              ],
            ),
            backgroundColor: Colors.grey[700],
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Failed to unsave'),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showCollectionSelector(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _CollectionSelectorSheet(
        recipeId: recipeId,
        userId: userId,
      ),
    );
  }
}

class _CollectionSelectorSheet extends StatefulWidget {
  final String recipeId;
  final String userId;

  const _CollectionSelectorSheet({
    required this.recipeId,
    required this.userId,
  });

  @override
  State<_CollectionSelectorSheet> createState() =>
      _CollectionSelectorSheetState();
}

class _CollectionSelectorSheetState extends State<_CollectionSelectorSheet> {
  final Set<String> _selectedCollections = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final collectionProvider = Provider.of<CollectionProvider>(
      context,
      listen: false,
    );
    await collectionProvider.loadCollections(widget.userId);
    
    // Check which collections already contain this recipe
    for (var collection in collectionProvider.collections) {
      final recipes = collection['recipes'] as List?;
      if (recipes != null && recipes.contains(widget.recipeId)) {
        _selectedCollections.add(collection['id']);
      }
    }
    
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Save to Collection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Collections List
          Consumer<CollectionProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final collections = provider.collections;

              if (collections.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.folder_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No collections yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a collection first',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final collectionId = collection['id'] as String;
                    final name = collection['name'] as String;
                    final recipeCount = (collection['recipes'] as List?)?.length ?? 0;
                    final isSelected = _selectedCollections.contains(collectionId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedCollections.add(collectionId);
                          } else {
                            _selectedCollections.remove(collectionId);
                          }
                        });
                      },
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      subtitle: Text(
                        '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Create New Collection Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showCreateCollectionDialog(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('Create New Collection'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 12),

          // Save Button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveToCollections,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Future<void> _saveToCollections() async {
    setState(() => _isSaving = true);

    try {
      final interactionProvider = Provider.of<InteractionProvider>(
        context,
        listen: false,
      );
      final collectionProvider = Provider.of<CollectionProvider>(
        context,
        listen: false,
      );

      // Ensure the recipe is marked as saved
      if (!interactionProvider.isRecipeSaved(widget.recipeId)) {
        await interactionProvider.toggleSave(widget.recipeId, widget.userId);
      }

      // Get all collections
      final allCollections = collectionProvider.collections;
      
      // Add to selected collections and remove from unselected ones
      for (var collection in allCollections) {
        final collectionId = collection['id'] as String;
        final recipes = (collection['recipes'] as List?)?.cast<String>() ?? [];
        final hasRecipe = recipes.contains(widget.recipeId);
        final isSelected = _selectedCollections.contains(collectionId);

        if (isSelected && !hasRecipe) {
          // Add to collection
          await collectionProvider.addRecipeToCollection(
            widget.userId,
            collectionId,
            widget.recipeId,
          );
        } else if (!isSelected && hasRecipe) {
          // Remove from collection
          await collectionProvider.removeRecipeFromCollection(
            widget.userId,
            collectionId,
            widget.recipeId,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedCollections.isEmpty
                      ? 'Recipe saved'
                      : 'Recipe saved to ${_selectedCollections.length} ${_selectedCollections.length == 1 ? 'collection' : 'collections'}',
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Failed to save recipe'),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showCreateCollectionDialog(BuildContext parentContext) {
    final controller = TextEditingController();
    
    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text(
          'Create New Collection',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Collection Name',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              try {
                final provider = Provider.of<CollectionProvider>(
                  parentContext,
                  listen: false,
                );
                await provider.createCollection(widget.userId, name);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text('Collection "$name" created'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  
                  // Reopen collection selector
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (parentContext.mounted) {
                      showModalBottomSheet(
                        context: parentContext,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        isScrollControlled: true,
                        builder: (context) => _CollectionSelectorSheet(
                          recipeId: widget.recipeId,
                          userId: widget.userId,
                        ),
                      );
                    }
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to create collection'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}