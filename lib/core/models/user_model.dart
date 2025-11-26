import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? name; // Name definition
  final String? photoURL;
  final String? profileImageUrl; // Alternative field name
  final String? bio;
  final String? phoneNumber;
  
  // Stats
  final int recipesCount;
  final int followersCount;
  final int followingCount;
  final int likesReceivedCount; // Total likes received on user's recipes
  
  // Settings
  final bool isPublic; // Public profile hay private
  final bool emailVerified;
  final List<String> preferences; // Food preferences, dietary restrictions
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.name,
    this.photoURL,
    this.profileImageUrl,
    this.bio,
    this.phoneNumber,
    this.recipesCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesReceivedCount = 0,
    this.isPublic = true,
    this.emailVerified = false,
    this.preferences = const [],
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  // Computed properties
  String get effectiveName => name ?? displayName ?? email.split('@')[0];
  String? get effectivePhotoUrl => profileImageUrl ?? photoURL;

  // Convert from Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      throw Exception('User document data is null');
    }
    
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      name: data['name'] as String?,
      photoURL: data['photoURL'] as String?,
      profileImageUrl: data['profileImageUrl'] as String? ?? data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      recipesCount: data['recipesCount'] as int? ?? 0,
      followersCount: data['followersCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      likesReceivedCount: data['likesReceivedCount'] as int? ?? 0,
      isPublic: data['isPublic'] as bool? ?? true,
      emailVerified: data['emailVerified'] as bool? ?? false,
      preferences: (data['preferences'] as List?)?.cast<String>() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert from Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      name: map['name'] as String?,
      photoURL: map['photoURL'] as String?,
      profileImageUrl: map['profileImageUrl'] as String? ?? map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      recipesCount: map['recipesCount'] as int? ?? 0,
      followersCount: map['followersCount'] as int? ?? 0,
      followingCount: map['followingCount'] as int? ?? 0,
      likesReceivedCount: map['likesReceivedCount'] as int? ?? 0,
      isPublic: map['isPublic'] as bool? ?? true,
      emailVerified: map['emailVerified'] as bool? ?? false,
      preferences: (map['preferences'] as List?)?.cast<String>() ?? [],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : map['updatedAt'] is DateTime
              ? map['updatedAt'] as DateTime
              : null,
      lastLoginAt: map['lastLoginAt'] is Timestamp
          ? (map['lastLoginAt'] as Timestamp).toDate()
          : map['lastLoginAt'] is DateTime
              ? map['lastLoginAt'] as DateTime
              : null,
    );
  }

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'name': name,
      'photoURL': photoURL,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'recipesCount': recipesCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'likesReceivedCount': likesReceivedCount,
      'isPublic': isPublic,
      'emailVerified': emailVerified,
      'preferences': preferences,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  // Convert to simple Map 
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'name': name,
      'photoURL': photoURL,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'recipesCount': recipesCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'likesReceivedCount': likesReceivedCount,
      'isPublic': isPublic,
      'emailVerified': emailVerified,
      'preferences': preferences,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  // CopyWith method for easy updates
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? name,
    String? photoURL,
    String? profileImageUrl,
    String? bio,
    String? phoneNumber,
    int? recipesCount,
    int? followersCount,
    int? followingCount,
    int? likesReceivedCount,
    bool? isPublic,
    bool? emailVerified,
    List<String>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      photoURL: photoURL ?? this.photoURL,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      recipesCount: recipesCount ?? this.recipesCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      likesReceivedCount: likesReceivedCount ?? this.likesReceivedCount,
      isPublic: isPublic ?? this.isPublic,
      emailVerified: emailVerified ?? this.emailVerified,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $effectiveName, bio: $bio)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Helper methods for UserModel

extension UserModelHelper on UserModel {
  // Create initial user document in Firestore
  static Future<void> createUserDocument({
    required String userId,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    final user = UserModel(
      id: userId,
      email: email,
      displayName: displayName,
      name: displayName,
      photoURL: photoURL,
      profileImageUrl: photoURL,
      bio: null,
      phoneNumber: null,
      recipesCount: 0,
      followersCount: 0,
      followingCount: 0,
      likesReceivedCount: 0,
      isPublic: true,
      emailVerified: false,
      preferences: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set(user.toFirestore());
  }

  // Update last login
  static Future<void> updateLastLogin(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}