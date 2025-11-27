import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

/// Model cho recipe draft
class RecipeDraft {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? coverImagePath; // Local file path
  final int serves;
  final int cookTimeSeconds;
  final String difficulty;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> steps;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeDraft({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.coverImagePath,
    required this.serves,
    required this.cookTimeSeconds,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'coverImagePath': coverImagePath,
      'serves': serves,
      'cookTimeSeconds': cookTimeSeconds,
      'difficulty': difficulty,
      'ingredients': json.encode(ingredients),
      'steps': json.encode(steps),
      'tags': json.encode(tags),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory RecipeDraft.fromJson(Map<String, dynamic> map) {
    return RecipeDraft(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      coverImagePath: map['coverImagePath'] as String?,
      serves: map['serves'] as int,
      cookTimeSeconds: map['cookTimeSeconds'] as int,
      difficulty: map['difficulty'] as String,
      ingredients: List<Map<String, dynamic>>.from(
        json.decode(map['ingredients'] as String),
      ),
      steps: List<Map<String, dynamic>>.from(
        json.decode(map['steps'] as String),
      ),
      tags: List<String>.from(
        json.decode(map['tags'] as String),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}

/// Service để quản lý recipe drafts locally
class DraftService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'recipe_drafts.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE drafts (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            coverImagePath TEXT,
            serves INTEGER NOT NULL,
            cookTimeSeconds INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            ingredients TEXT NOT NULL,
            steps TEXT NOT NULL,
            tags TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        
        // Index for faster queries
        await db.execute('''
          CREATE INDEX idx_user_updated 
          ON drafts(userId, updatedAt DESC)
        ''');
        
        debugPrint('[DRAFT] Database created');
      },
    );
  }

  // ==================== CREATE ====================

  /// Save draft to local database
  static Future<String> saveDraft(RecipeDraft draft) async {
    final db = await database;
    
    await db.insert(
      'drafts',
      draft.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    debugPrint('[DRAFT] Draft saved: ${draft.id}');
    return draft.id;
  }

  // ==================== READ ====================

  /// Get all drafts for a user
  static Future<List<RecipeDraft>> getDrafts(String userId) async {
    final db = await database;
    
    final results = await db.query(
      'drafts',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );

    return results.map((map) => RecipeDraft.fromJson(map)).toList();
  }

  /// Get single draft by ID
  static Future<RecipeDraft?> getDraft(String draftId) async {
    final db = await database;
    
    final results = await db.query(
      'drafts',
      where: 'id = ?',
      whereArgs: [draftId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return RecipeDraft.fromJson(results.first);
  }

  /// Get draft count for user
  static Future<int> getDraftCount(String userId) async {
    final db = await database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM drafts WHERE userId = ?',
      [userId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== UPDATE ====================

  /// Update existing draft
  static Future<void> updateDraft(RecipeDraft draft) async {
    final db = await database;
    
    await db.update(
      'drafts',
      draft.toJson(),
      where: 'id = ?',
      whereArgs: [draft.id],
    );
    
    debugPrint('[DRAFT] Draft updated: ${draft.id}');
  }

  // ==================== DELETE ====================

  /// Delete draft
  static Future<void> deleteDraft(String draftId) async {
    final db = await database;
    
    await db.delete(
      'drafts',
      where: 'id = ?',
      whereArgs: [draftId],
    );
    
    debugPrint('[DRAFT] Draft deleted: $draftId');
  }

  /// Delete all drafts for a user
  static Future<void> deleteAllDrafts(String userId) async {
    final db = await database;
    
    final count = await db.delete(
      'drafts',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    
    debugPrint('[DRAFT] Deleted $count drafts for user: $userId');
  }

  // ==================== UTILITY ====================

  /// Create new empty draft
  static RecipeDraft createEmptyDraft(String userId) {
    final now = DateTime.now();
    return RecipeDraft(
      id: 'draft_${now.millisecondsSinceEpoch}',
      userId: userId,
      title: '',
      description: '',
      serves: 1,
      cookTimeSeconds: 0,
      difficulty: 'medium',
      ingredients: [],
      steps: [],
      tags: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Auto-save draft
  static Future<void> autoSaveDraft(RecipeDraft draft) async {
    final updatedDraft = RecipeDraft(
      id: draft.id,
      userId: draft.userId,
      title: draft.title,
      description: draft.description,
      coverImagePath: draft.coverImagePath,
      serves: draft.serves,
      cookTimeSeconds: draft.cookTimeSeconds,
      difficulty: draft.difficulty,
      ingredients: draft.ingredients,
      steps: draft.steps,
      tags: draft.tags,
      createdAt: draft.createdAt,
      updatedAt: DateTime.now(), // Update timestamp
    );
    
    await saveDraft(updatedDraft);
  }
}