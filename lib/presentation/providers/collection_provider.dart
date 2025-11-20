import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get collections => _collections;
  bool get isLoading => _isLoading;

  // Load collections for a user
  Future<void> loadCollections(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('collections')
          .orderBy('createdAt', descending: true)
          .get();

      _collections = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading collections: $e');
      _collections = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create a new collection
  Future<void> createCollection(String userId, String name) async {
    final collectionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc();

    await collectionRef.set({
      'name': name,
      'recipes': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await loadCollections(userId);
  }

  // Rename an existing collection
  Future<void> renameCollection(
    String userId,
    String collectionId,
    String newName,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionId)
        .update({'name': newName});

    await loadCollections(userId);
  }

  // Delete a collection
  Future<void> deleteCollection(String userId, String collectionId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionId)
        .delete();

    await loadCollections(userId);
  }

  // Add a recipe to a collection
  Future<void> addRecipeToCollection(
    String userId,
    String collectionId,
    String recipeId,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionId)
        .update({
      'recipes': FieldValue.arrayUnion([recipeId]),
    });

    await loadCollections(userId);
  }

  // Remove a recipe from a collection
  Future<void> removeRecipeFromCollection(
    String userId,
    String collectionId,
    String recipeId,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('collections')
        .doc(collectionId)
        .update({
      'recipes': FieldValue.arrayRemove([recipeId]),
    });

    await loadCollections(userId);
  }
}