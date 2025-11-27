import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../providers/draft_provider.dart';
import '../../../screens/main/recipes/create_recipe_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/draft_service.dart';
import 'dart:io';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({Key? key}) : super(key: key);

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final provider = Provider.of<DraftProvider>(context, listen: false);
    await provider.loadDrafts(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drafts, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please login to view drafts',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color:AppColors.primary,
        ),
        title: const Text(
          'Recipe Drafts',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        actions: [
          Consumer<DraftProvider>(
            builder: (context, provider, _) {
              if (provider.drafts.isEmpty) return const SizedBox.shrink();
              
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppColors.primary),
                onSelected: (value) {
                  if (value == 'delete_all') {
                    _confirmDeleteAll(context, user.uid);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Delete all drafts'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<DraftProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (provider.drafts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.drafts,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No drafts yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your recipe drafts will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadDrafts,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.drafts.length,
              itemBuilder: (context, index) {
                final draft = provider.drafts[index];
                return _DraftCard(
                  draft: draft,
                  onTap: () {
                    // Navigate to edit draft screen
                    _editDraft(context, draft);
                  },
                  onDelete: () async {
                    await provider.deleteDraft(draft.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Draft deleted'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewDraft(context, user.uid),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Draft',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          )
        ),
      ),
    );
  }

  void _createNewDraft(BuildContext context, String userId) async {
    // Navigate to CreateRecipeScreen without draftId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateRecipeScreen(),
      ),
    ).then((_) {
      // Reload drafts when coming back
      _loadDrafts();
    });
  }

  void _editDraft(BuildContext context, RecipeDraft draft) {
    // Navigate to CreateRecipeScreen with draftId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRecipeScreen(draftId: draft.id),
      ),
    ).then((_) {
      // Reload drafts when coming back
      _loadDrafts();
    });
  }

  void _confirmDeleteAll(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Drafts?'),
        content: const Text(
          'This will permanently delete all your recipe drafts. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final provider = Provider.of<DraftProvider>(
                context,
                listen: false,
              );
              
              await provider.deleteAllDrafts(userId);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All drafts deleted'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final RecipeDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = draft.title.isNotEmpty || 
                       draft.description.isNotEmpty ||
                       draft.ingredients.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: draft.coverImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(draft.coverImagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image,
                              color: Colors.grey[400],
                              size: 30,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.restaurant_menu,
                        color: Colors.grey[400],
                        size: 30,
                      ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.isEmpty ? 'Untitled Recipe' : draft.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: draft.title.isEmpty 
                            ? Colors.grey[500] 
                            : AppColors.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    if (draft.description.isNotEmpty) ...[
                      Text(
                        draft.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Updated ${timeago.format(draft.updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (hasContent) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.kitchen, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${draft.ingredients.length} items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Draft?'),
                      content: const Text(
                        'This draft will be permanently deleted.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}