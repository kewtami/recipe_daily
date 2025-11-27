import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_daily/core/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import 'recipes/recipe_detail_screen.dart';
import 'profile/user_profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  // Mark notification as read
  Future<void> _markAsRead(String userId, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> _markAllAsRead(BuildContext context, String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark all as read'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
              Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please login to view notifications',
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
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        actions: [
          // Mark all as read button
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              
              if (!hasUnread) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.done_all, color: AppColors.primary),
                tooltip: 'Mark all as read',
                onPressed: () => _markAllAsRead(context, user.uid),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll notify you when something happens',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          final groupedNotifications = _groupNotifications(notifications);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (groupedNotifications['today']?.isNotEmpty ?? false) ...[
                const _SectionHeader(title: 'Today'),
                const SizedBox(height: 12),
                ...groupedNotifications['today']!
                    .map((notif) => _NotificationItem(
                          notification: notif,
                          userId: user.uid,
                          onMarkAsRead: _markAsRead,
                        ))
                    .toList(),
                const SizedBox(height: 24),
              ],
              if (groupedNotifications['yesterday']?.isNotEmpty ?? false) ...[
                const _SectionHeader(title: 'Yesterday'),
                const SizedBox(height: 12),
                ...groupedNotifications['yesterday']!
                    .map((notif) => _NotificationItem(
                          notification: notif,
                          userId: user.uid,
                          onMarkAsRead: _markAsRead,
                        ))
                    .toList(),
                const SizedBox(height: 24),
              ],
              if (groupedNotifications['thisWeek']?.isNotEmpty ?? false) ...[
                const _SectionHeader(title: 'This Week'),
                const SizedBox(height: 12),
                ...groupedNotifications['thisWeek']!
                    .map((notif) => _NotificationItem(
                          notification: notif,
                          userId: user.uid,
                          onMarkAsRead: _markAsRead,
                        ))
                    .toList(),
                const SizedBox(height: 24),
              ],
              if (groupedNotifications['older']?.isNotEmpty ?? false) ...[
                const _SectionHeader(title: 'Older'),
                const SizedBox(height: 12),
                ...groupedNotifications['older']!
                    .map((notif) => _NotificationItem(
                          notification: notif,
                          userId: user.uid,
                          onMarkAsRead: _markAsRead,
                        ))
                    .toList(),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<QueryDocumentSnapshot>> _groupNotifications(
    List<QueryDocumentSnapshot> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    return {
      'today': notifications.where((notif) {
        final createdAt = (notif.data() as Map)['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isAfter(today);
      }).toList(),
      'yesterday': notifications.where((notif) {
        final createdAt = (notif.data() as Map)['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isAfter(yesterday) && date.isBefore(today);
      }).toList(),
      'thisWeek': notifications.where((notif) {
        final createdAt = (notif.data() as Map)['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isAfter(weekAgo) && date.isBefore(yesterday);
      }).toList(),
      'older': notifications.where((notif) {
        final createdAt = (notif.data() as Map)['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isBefore(weekAgo);
      }).toList(),
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }
}

class _NotificationItem extends StatefulWidget {
  final QueryDocumentSnapshot notification;
  final String userId;
  final Future<void> Function(String userId, String notificationId) onMarkAsRead;

  const _NotificationItem({
    required this.notification,
    required this.userId,
    required this.onMarkAsRead,
  });

  @override
  State<_NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<_NotificationItem> {
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final data = widget.notification.data() as Map<String, dynamic>;
    if (data['type'] != 'follow') return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final followerId = data['fromUserId'] as String?;
    if (followerId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(followerId)
          .get();

      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
  final data = widget.notification.data() as Map<String, dynamic>;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final followerId = data['fromUserId'] as String?;
  if (followerId == null) return;

  setState(() {
    _isFollowing = !_isFollowing;
  });

  try {
    final batch = FirebaseFirestore.instance.batch();
    
    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(followerId);

    final followerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(followerId)
        .collection('followers')
        .doc(user.uid);

    if (_isFollowing) {
      // Follow
      batch.set(followingRef, {
        'followedAt': FieldValue.serverTimestamp(),
      });
      batch.set(followerRef, {
        'followedAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Create notification after successful follow
      await NotificationService.createFollowNotification(
        followedUserId: followerId,
        followerUserId: user.uid,
        followerUserName: user.displayName ?? 'User',
        followerUserPhoto: user.photoURL,
      );
    } else {
      // Unfollow
      batch.delete(followingRef);
      batch.delete(followerRef);
      await batch.commit();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowing
                ? 'Now following ${data['fromUserName']}'
                : 'Unfollowed ${data['fromUserName']}',
          ),
          backgroundColor:
              _isFollowing ? AppColors.success : Colors.grey[700],
          duration: const Duration(seconds: 1),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _isFollowing = !_isFollowing;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update follow status'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

  void _handleTap() {
    final data = widget.notification.data() as Map<String, dynamic>;
    final type = data['type'] as String;
    final recipeId = data['recipeId'] as String?;
    
    // Mark as read when tapped
    if (data['read'] != true) {
      widget.onMarkAsRead(widget.userId, widget.notification.id);
    }

    // Navigate based on type
    if (type == 'follow') {
      // Navigate to user profile
      final fromUserId = data['fromUserId'] as String?;
      final fromUserName = data['fromUserName'] as String?;
      
      if (fromUserId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: fromUserId,
              userName: fromUserName,
            ),
          ),
        );
      }
    } else if (recipeId != null && (type == 'like' || type == 'comment' || type == 'save')) {
      // Navigate to recipe
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipeId: recipeId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.notification.data() as Map<String, dynamic>;
    final type = data['type'] as String;
    final fromUserName = data['fromUserName'] as String? ?? 'Someone';
    final fromUserPhoto = data['fromUserPhotoUrl'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final recipeId = data['recipeId'] as String?;
    final recipeImage = data['recipeImage'] as String?;
    final isRead = data['read'] == true;

    IconData icon;
    Color iconColor;
    String message;
    Widget? actionWidget;

    switch (type) {
      case 'follow':
        icon = Icons.person_add;
        iconColor = AppColors.primary;
        message = 'now following you';
        actionWidget = _buildFollowButton();
        break;
      case 'like':
        icon = Icons.favorite;
        iconColor = Colors.red;
        message = 'liked your recipe';
        break;
      case 'save':
        icon = Icons.bookmark;
        iconColor = AppColors.primary;
        message = 'saved your recipe';
        break;
      case 'comment':
        icon = Icons.comment;
        iconColor = AppColors.primary;
        message = 'commented on your recipe';
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
        message = 'interacted with you';
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // User Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  fromUserPhoto != null ? NetworkImage(fromUserPhoto) : null,
              child: fromUserPhoto == null
                  ? Text(
                      fromUserName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.secondary,
                      ),
                      children: [
                        TextSpan(
                          text: fromUserName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (type == 'follow' && data['additionalUsers'] != null)
                          TextSpan(
                            text: ' and ',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        if (type == 'follow' && data['additionalUsers'] != null)
                          TextSpan(
                            text: data['additionalUserName'] as String? ?? 'others',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        TextSpan(
                          text: ' $message',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Unread indicator
            if (!isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Action or Recipe Image
            if (actionWidget != null)
              actionWidget
            else if (recipeImage != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recipeImage,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 24),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isFollowing ? Colors.grey[200] : AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: GestureDetector(
        onTap: _toggleFollow,
        child: Text(
          _isFollowing ? 'Followed' : 'Follow',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _isFollowing ? AppColors.secondary : Colors.white,
          ),
        ),
      ),
    );
  }
}