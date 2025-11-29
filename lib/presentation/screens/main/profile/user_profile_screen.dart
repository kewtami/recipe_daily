import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/recipes/recipe_cards.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/recipe_model.dart';
import '../../../widgets/interactions/follow_button.dart';
import '../recipes/recipe_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    this.userName,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // User data
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;
  
  // Recipes
  List<RecipeModel> _userRecipes = [];
  bool _isLoadingRecipes = true;
  
  // Real-time stats
  int _recipesCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  int _likesCount = 0;

  // Stream subscriptions for real-time updates
  Stream<QuerySnapshot>? _recipesStream;
  Stream<QuerySnapshot>? _followersStream;
  Stream<QuerySnapshot>? _followingStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    _loadUserData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Setup real-time listeners for stats
  void _setupRealtimeListeners() {
    // Listen to recipes changes
    _recipesStream = FirebaseFirestore.instance
        .collection('recipes')
        .where('authorId', isEqualTo: widget.userId)
        .snapshots();

    _recipesStream!.listen((snapshot) {
      if (mounted) {
        setState(() {
          _userRecipes = snapshot.docs
              .map((doc) => RecipeModel.fromFirestore(doc))
              .toList();
          _recipesCount = snapshot.docs.length;
          _isLoadingRecipes = false;
        });
        
        // Calculate total likes from recipes
        _calculateTotalLikes();
      }
    });

    // Listen to followers changes
    _followersStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .snapshots();

    _followersStream!.listen((snapshot) {
      if (mounted) {
        setState(() {
          _followersCount = snapshot.docs.length;
        });
      }
    });

    // Listen to following changes
    _followingStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('following')
        .snapshots();

    _followingStream!.listen((snapshot) {
      if (mounted) {
        setState(() {
          _followingCount = snapshot.docs.length;
        });
      }
    });
  }

  // Calculate total likes from all user recipes
  void _calculateTotalLikes() {
    int totalLikes = 0;
    for (var recipe in _userRecipes) {
      totalLikes += recipe.likesCount;
    }
    
    if (mounted) {
      setState(() {
        _likesCount = totalLikes;
      });
    }
    
    debugPrint('Total likes calculated: $totalLikes');
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('Loading user data for: ${widget.userId}');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _userData = userDoc.data();
          _isLoadingUser = false;
        });
        debugPrint('User data loaded: ${_userData?['displayName']}');
      } else {
        debugPrint('User document does not exist!');
        if (mounted) {
          setState(() {
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
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
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser?.uid == widget.userId;

    // If viewing own profile, redirect to ProfileScreen
    if (isCurrentUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoadingUser) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              pinned: false,
              floating: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                _userData?['displayName'] ?? widget.userName ?? 'User',
                style: const TextStyle(color: AppColors.secondary),
              ),
            ),
            
            // Profile Info
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _userData?['photoURL'] != null
                        ? NetworkImage(_userData!['photoURL'])
                        : null,
                    child: _userData?['photoURL'] == null
                        ? Text(
                            (_userData?['displayName'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // User Name
                  Text(
                    _userData?['displayName'] ?? widget.userName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Row - REAL-TIME DATA
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          _recipesCount.toString(),
                          'Recipes',
                        ),
                        _buildStatItem(
                          _formatCount(_followingCount),
                          'Following',
                        ),
                        _buildStatItem(
                          _followersCount.toString(),
                          'Followers',
                        ),
                        _buildStatItem(
                          _formatCount(_likesCount),
                          'Likes',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bio
                  if (_userData?['bio'] != null && _userData!['bio'].toString().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _userData!['bio'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 24),
                  
                  // Follow Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: FollowButton(
                      targetUserId: widget.userId,
                      targetUserName: _userData?['displayName'] ?? 
                          widget.userName ?? 
                          'User',
                      onFollowChanged: () {
                        // Stats will update automatically via streams
                        debugPrint('Follow status changed');
                      },
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
                            onTap: () => _tabController.animateTo(0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _tabController.index == 0
                                    ? AppColors.primary
                                    : Colors.white,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
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
                            onTap: () => _tabController.animateTo(1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _tabController.index == 1
                                    ? AppColors.primary
                                    : Colors.white,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
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
            
            // Grid Content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _tabController.index == 0
                  ? _buildRecipesGrid()
                  : _buildPrivateMessage(),
            ),
          ],
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
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRecipesGrid() {
    if (_isLoadingRecipes) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_userRecipes.isEmpty) {
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
          final recipe = _userRecipes[index];
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
        },
        childCount: _userRecipes.length,
      ),
    );
  }

  Widget _buildPrivateMessage() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Liked recipes are private',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}