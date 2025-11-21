import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/recipe_model.dart';
import '../../../providers/collection_provider.dart';
import '../../../widgets/recipes/recipe_cards.dart';
import '../recipes/recipe_detail_screen.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  final String collectionName;

  const CollectionDetailScreen({
    Key? key,
    required this.collectionId,
    required this.collectionName,
  }) : super(key: key);

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<RecipeModel> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get collection data
      final collectionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .doc(widget.collectionId)
          .get();

      if (!collectionDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final recipeIds =
          (collectionDoc.data()?['recipes'] as List?)?.cast<String>() ?? [];

      if (recipeIds.isEmpty) {
        setState(() {
          _recipes = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch recipes
      final recipeDocs = await Future.wait(
        recipeIds.map((id) =>
            FirebaseFirestore.instance.collection('recipes').doc(id).get()),
      );

      final recipes = recipeDocs
          .where((doc) => doc.exists)
          .map((doc) => RecipeModel.fromFirestore(doc))
          .toList();

      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading collection recipes: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showCollectionOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: const Text('Rename Collection'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Collection'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteCollection();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.collectionName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Collection Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == widget.collectionName) {
                Navigator.pop(context);
                return;
              }

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                final provider = Provider.of<CollectionProvider>(
                  context,
                  listen: false,
                );
                await provider.renameCollection(
                  user.uid,
                  widget.collectionId,
                  newName,
                );

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to saved recipes
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Collection renamed'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to rename collection'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCollection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text(
          'Are you sure you want to delete "${widget.collectionName}"? The recipes will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                final provider = Provider.of<CollectionProvider>(
                  context,
                  listen: false,
                );
                await provider.deleteCollection(user.uid, widget.collectionId);

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to saved recipes
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Collection deleted'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete collection'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

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
          widget.collectionName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.secondary),
            onPressed: _showCollectionOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recipes in this collection',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start adding recipes!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadRecipes,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _recipes.length,
                    itemBuilder: (context, index) {
                      return RecipeCard(
                        recipe: _recipes[index],
                        onTap: () {
                          // Navigate to recipe detail when tapped
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(
                                recipeId: _recipes[index].id,
                                hideAuthor: _recipes[index].authorId ==
                                    FirebaseAuth.instance.currentUser?.uid,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}