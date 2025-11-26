import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';

class FollowButton extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final VoidCallback? onFollowChanged;

  const FollowButton({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
    this.onFollowChanged,
  }) : super(key: key);

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(widget.targetUserId)
          .get();

      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to follow users'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Don't allow following yourself
    if (user.uid == widget.targetUserId) {
      return;
    }

    setState(() {
      _isUpdating = true;
      _isFollowing = !_isFollowing; // Optimistic update
    });

    try {
      final batch = FirebaseFirestore.instance.batch();

      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(widget.targetUserId);

      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
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

        // Create notification
        await NotificationService.createFollowNotification(
          followedUserId: widget.targetUserId,
          followerUserId: user.uid,
          followerUserName: user.displayName ?? 'User',
          followerUserPhoto: user.photoURL,
        );
      } else {
        // Unfollow
        batch.delete(followingRef);
        batch.delete(followerRef);
      }

      await batch.commit();

      widget.onFollowChanged?.call();

      if (mounted) {
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
                      ? 'Now following ${widget.targetUserName}'
                      : 'Unfollowed ${widget.targetUserName}',
                ),
              ],
            ),
            backgroundColor: _isFollowing ? AppColors.success : Colors.grey[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isFollowing = !_isFollowing;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Failed to update follow status'),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey[300] : AppColors.primary,
          foregroundColor: _isFollowing ? AppColors.secondary : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isUpdating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Text(
                    _isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}