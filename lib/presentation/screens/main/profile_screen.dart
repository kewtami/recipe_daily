import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:recipe_daily/presentation/providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/interaction_provider.dart';
import '../../widgets/recipes/recipe_cards.dart';
import '../../widgets/recipes/recipe_options_bottom_sheet.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/recipe_model.dart';
import 'recipes/recipe_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Add listener to tab controller
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Provider.of<RecipeProvider>(context, listen: false)
            .subscribeToUserRecipes(user.uid);
        Provider.of<UserProvider>(context, listen: false)
            .subscribeToUserStats(user.uid);
        Provider.of<UserProvider>(context, listen: false)
            .loadUserProfile(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isGoogleUser(User? user) {
    return user?.providerData.any(
      (provider) => provider.providerId == 'google.com'
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer3<RecipeProvider, InteractionProvider, UserProvider>(
          builder: (context, recipeProvider, interactionProvider, userProvider, _) {
            final userRecipes = recipeProvider.recipes;
            final recipesCount = userRecipes.length;
            final stats = userProvider.userStats;
            final userProfile = userProvider.userProfile;
            
            // Get liked recipe IDs
            final likedRecipeIds = interactionProvider.likedRecipeIds.toList();
            
            return CustomScrollView(
              slivers: [
                // App Bar with More Button
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: false,
                  floating: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: AppColors.primary),
                      onPressed: () => _showMoreMenu(context),
                    ),
                  ],
                ),
                
                // Profile Info
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Avatar with Edit Icon
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: user?.photoURL != null 
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? const Icon(
                                  Icons.person, 
                                  size: 60, 
                                  color: Colors.white
                                )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit, 
                                size: 16, 
                                color: Colors.white
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // User Name
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Stats Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(stats.recipesCount.toString(), 'Recipes'),
                            _buildStatItem(_formatCount(stats.followingCount), 'Following'),
                            _buildStatItem(stats.followersCount.toString(), 'Followers'),
                            _buildStatItem(_formatCount(stats.likesCount), 'Likes'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bio
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          '"Tell me what you eat, and I will tell you what you are"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Tab Selector
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _tabController.animateTo(0);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _tabController.index == 0 
                                        ? AppColors.primary 
                                        : Colors.white,
                                    border: Border.all(
                                      color: AppColors.primary, 
                                      width: 2
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Recipes',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _tabController.index == 0 
                                          ? Colors.white 
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _tabController.animateTo(1);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _tabController.index == 1 
                                        ? AppColors.primary 
                                        : Colors.white,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Liked',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _tabController.index == 1 
                                          ? Colors.white 
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _tabController.index == 0
                      ? _buildRecipesGrid(userRecipes)
                      : _buildLikedGrid(likedRecipeIds),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, 
            color: Colors.grey[600]
          ),
        ),
      ],
    );
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

  Widget _buildRecipesGrid(List<RecipeModel> recipes) {
    if (recipes.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No recipes yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final recipe = recipes[index];
          return RecipeCard(
            recipe: recipe,
            showMoreButton: true,
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
            showOnlyOwnerRecipes: true,
            onMoreTap: () => _showRecipeOptions(context, recipe),
          );
        },
        childCount: recipes.length,
      ),
    );
  }

  Widget _buildLikedGrid(List<String> likedRecipeIds) {
    if (likedRecipeIds.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No liked recipes yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Recipes you like will appear here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // Fetch recipes by IDs using FutureBuilder
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final recipeId = likedRecipeIds[index];
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('recipes')
                .doc(recipeId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                  ),
                );
              }

              try {
                final recipe = RecipeModel.fromFirestore(snapshot.data!);
                return RecipeCard(
                  recipe: recipe,
                  showMoreButton: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeDetailScreen(
                          recipeId: recipe.id,
                          hideAuthor: false,
                        ),
                      ),
                    );
                  },
                  showOnlyOwnerRecipes: false,
                );
              } catch (e) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                  ),
                );
              }
            },
          );
        },
        childCount: likedRecipeIds.length,
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
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
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.primary),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline, color: AppColors.primary),
                title: const Text('Help & Support'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                title: const Text('Privacy Policy'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: const Text('Delete Account'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteAccountDialog(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.primary),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.primary)
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Logging out...'),
                    ],
                  ),
                  duration: Duration(seconds: 1),
                ),
              );
              
              final authProvider = Provider.of<AuthProvider>(
                context, 
                listen: false
              );
              await authProvider.signOut();
            },
            child: const Text(
              'Logout', 
              style: TextStyle(color: AppColors.error)
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser = _isGoogleUser(user);
    
    final TextEditingController passwordController = TextEditingController();
    bool isDeleting = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone!\n\n'
                'All your data will be deleted:\n'
                '• Account information\n'
                '• Saved recipes\n'
                '• All personal data',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (!isGoogleUser) ...[
                const Text(
                  'Please enter your password to confirm:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isDeleting,
                  decoration: const InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else
                const Text(
                  '\n✓ Google account - no password required',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () {
                passwordController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isDeleting ? null : () async {
                if (!isGoogleUser && passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your password'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                setState(() {
                  isDeleting = true;
                });
                
                try {
                  if (user == null) throw Exception('No user logged in');

                  if (isGoogleUser) {
                    await user.delete();
                  } else {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);
                    await user.delete();
                  }
                  
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deleted successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  setState(() {
                    isDeleting = false;
                  });
                  
                  String message = 'Failed to delete account';
                  switch (e.code) {
                    case 'wrong-password':
                      message = 'Incorrect password';
                      break;
                    case 'requires-recent-login':
                      message = 'Please logout and login again, then try deleting';
                      break;
                    case 'too-many-requests':
                      message = 'Too many attempts. Please try again later';
                      break;
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: AppColors.error,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  setState(() {
                    isDeleting = false;
                  });
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                } finally {
                  passwordController.dispose();
                }
              },
              child: isDeleting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Delete',
                    style: TextStyle(
                      color: AppColors.error, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipeOptions(BuildContext context, RecipeModel recipe) {
    RecipeOptionsBottomSheet.show(
      context: context,
      recipe: recipe,
      mode: 'owner',
    );
  }
}