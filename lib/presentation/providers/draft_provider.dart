import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/services/draft_service.dart';

class DraftProvider extends ChangeNotifier {
  List<RecipeDraft> _drafts = [];
  bool _isLoading = false;
  RecipeDraft? _currentDraft;

  List<RecipeDraft> get drafts => _drafts;
  bool get isLoading => _isLoading;
  RecipeDraft? get currentDraft => _currentDraft;

  // Auto-save timer
  Timer? _autoSaveTimer;

  // ==================== LOAD ====================

  Future<void> loadDrafts(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _drafts = await DraftService.getDrafts(userId);
      debugPrint('[DRAFT] Loaded ${_drafts.length} drafts');
    } catch (e) {
      debugPrint('[DRAFT] Error loading drafts: $e');
      _drafts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== CREATE ====================

  Future<RecipeDraft> createNewDraft(String userId) async {
    final draft = DraftService.createEmptyDraft(userId);
    await DraftService.saveDraft(draft);
    
    _drafts.insert(0, draft);
    _currentDraft = draft;
    
    notifyListeners();
    debugPrint('[DRAFT] New draft created: ${draft.id}');
    
    return draft;
  }

  // ==================== UPDATE ====================

  Future<void> updateDraft(RecipeDraft draft) async {
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
      updatedAt: DateTime.now(),
    );

    await DraftService.updateDraft(updatedDraft);
    
    // Update in list
    final index = _drafts.indexWhere((d) => d.id == draft.id);
    if (index != -1) {
      _drafts[index] = updatedDraft;
    }
    
    if (_currentDraft?.id == draft.id) {
      _currentDraft = updatedDraft;
    }
    
    notifyListeners();
    debugPrint('[DRAFT] Draft updated: ${draft.id}');
  }

  // ==================== AUTO-SAVE ====================

  void scheduleAutoSave(RecipeDraft draft) {
    _autoSaveTimer?.cancel();
    
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      DraftService.autoSaveDraft(draft);
      debugPrint('[DRAFT] Auto-saved: ${draft.id}');
    });
  }

  // ==================== DELETE ====================

  Future<void> deleteDraft(String draftId) async {
    await DraftService.deleteDraft(draftId);
    
    _drafts.removeWhere((d) => d.id == draftId);
    
    if (_currentDraft?.id == draftId) {
      _currentDraft = null;
    }
    
    notifyListeners();
    debugPrint('[DRAFT] Draft deleted: $draftId');
  }

  Future<void> deleteAllDrafts(String userId) async {
    await DraftService.deleteAllDrafts(userId);
    
    _drafts.clear();
    _currentDraft = null;
    
    notifyListeners();
    debugPrint('[DRAFT] All drafts deleted');
  }

  // ==================== SET CURRENT ====================

  Future<void> setCurrentDraft(String draftId) async {
    final draft = await DraftService.getDraft(draftId);
    _currentDraft = draft;
    notifyListeners();
  }

  void clearCurrentDraft() {
    _currentDraft = null;
    notifyListeners();
  }

  // ==================== CLEANUP ====================

  void clearCache() {
    _drafts.clear();
    _currentDraft = null;
    _autoSaveTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}