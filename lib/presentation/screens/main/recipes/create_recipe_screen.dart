import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_daily/presentation/screens/main/main_screen.dart';
import 'dart:io';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/recipe_model.dart';
import '../../../../core/services/calorie_service.dart';
import '../../../../core/services/draft_service.dart';
import '../../../providers/recipe_provider.dart';
import '../../../providers/draft_provider.dart';
import '../../../widgets/common/custom_button.dart';

class CreateRecipeScreen extends StatefulWidget {
  final String? draftId; // Load existing draft
  
  const CreateRecipeScreen({
    Key? key,
    this.draftId,
  }) : super(key: key);

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _servesController = TextEditingController(text: '1');
  
  // Cook Time Controllers (HH:MM:SS format)
  final _hoursController = TextEditingController(text: '00');
  final _minutesController = TextEditingController(text: '45');
  final _secondsController = TextEditingController(text: '00');
  
  File? _coverImage;
  Difficulty _difficulty = Difficulty.medium;
  
  // Dynamic Ingredients
  final List<IngredientInput> _ingredients = [
    IngredientInput(),
    IngredientInput(),
  ];
  
  // Dynamic Steps
  final List<StepInput> _steps = [
    StepInput(stepNumber: 1),
  ];
  
  // Tags
  final List<String> _selectedTags = [];
  final List<String> _availableTags = [
    'Vegan', 'Vegetarian', 'Gluten-Free', 'Dairy-Free',
    'Breakfast', 'Lunch', 'Dinner', 'Dessert', 'Snack',
    'Quick', 'Easy', 'Healthy', 'Low-Carb', 'High-Protein',
  ];

  // Common ingredients for autocomplete
  final List<String> _commonIngredients = [
    'Chicken Breast', 'Beef', 'Pork', 'Salmon', 'Shrimp', 'Tofu',
    'Rice', 'Pasta', 'Bread', 'Flour', 'Eggs', 'Milk', 'Butter',
    'Cheese', 'Yogurt', 'Olive Oil', 'Vegetable Oil', 'Coconut Oil',
    'Tomato', 'Onion', 'Garlic', 'Carrot', 'Potato', 'Broccoli',
    'Spinach', 'Bell Pepper', 'Mushroom', 'Lettuce', 'Cucumber',
    'Sugar', 'Salt', 'Pepper', 'Soy Sauce', 'Fish Sauce', 'Honey',
    'Lemon', 'Lime', 'Ginger', 'Chili', 'Basil', 'Cilantro',
  ];

  int _totalCalories = 0;
  bool _isCalculatingCalories = false;
  final CalorieService _calorieService = CalorieService();

  // ========== DRAFT SUPPORT ==========
  String? _currentDraftId;
  Timer? _autoSaveTimer;
  DateTime? _lastSaveTime;
  bool _isSavingDraft = false;
  
  @override
  void initState() {
    super.initState();
    _initializeDraft();
    _setupAutoSave();
  }

  Future<void> _initializeDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (widget.draftId != null) {
      // Load existing draft
      await _loadDraft(widget.draftId!);
    } else {
      // Create new draft
      final draftProvider = Provider.of<DraftProvider>(context, listen: false);
      final draft = await draftProvider.createNewDraft(user.uid);
      _currentDraftId = draft.id;
      debugPrint('[DRAFT] New draft created: $_currentDraftId');
    }
  }

  Future<void> _loadDraft(String draftId) async {
    try {
      final draft = await DraftService.getDraft(draftId);
      if (draft == null) return;

      setState(() {
        _currentDraftId = draft.id;
        _titleController.text = draft.title;
        _descriptionController.text = draft.description;
        _servesController.text = draft.serves.toString();
        
        // Load cook time
        final cookTime = Duration(seconds: draft.cookTimeSeconds);
        _hoursController.text = cookTime.inHours.toString().padLeft(2, '0');
        _minutesController.text = (cookTime.inMinutes % 60).toString().padLeft(2, '0');
        _secondsController.text = (cookTime.inSeconds % 60).toString().padLeft(2, '0');
        
        _difficulty = Difficulty.values.firstWhere(
          (d) => d.name == draft.difficulty,
          orElse: () => Difficulty.medium,
        );
        
        // Load cover image if exists
        if (draft.coverImagePath != null) {
          _coverImage = File(draft.coverImagePath!);
        }
        
        // Load ingredients
        _ingredients.clear();
        for (var ingData in draft.ingredients) {
          final ing = IngredientInput();
          ing.quantityController.text = ingData['quantity'].toString();
          ing.unit = ingData['unit'] ?? 'g';
          ing.nameController.text = ingData['name'] ?? '';
          ing.method = CookingMethod.values.firstWhere(
            (m) => m.name == ingData['method'],
            orElse: () => CookingMethod.raw,
          );
          ing.calories = ingData['calories'] ?? 0;
          _ingredients.add(ing);
        }
        
        // Load steps
        _steps.clear();
        for (var stepData in draft.steps) {
          final step = StepInput(stepNumber: stepData['stepNumber'] ?? 1);
          step.instructionController.text = stepData['instruction'] ?? '';
          // Cannot load step images from draft
          _steps.add(step);
        }
        
        // Load tags
        _selectedTags.addAll(draft.tags);
      });
      
      // Calculate calories
      await _calculateTotalCalories();
      
      debugPrint('[DRAFT] Draft loaded: $draftId');
    } catch (e) {
      debugPrint('[DRAFT] Error loading draft: $e');
    }
  }

  void _setupAutoSave() {
    // Listen to all text controllers
    _titleController.addListener(_scheduleAutoSave);
    _descriptionController.addListener(_scheduleAutoSave);
    _servesController.addListener(_scheduleAutoSave);
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      _saveDraft(showSnackbar: false);
    });
  }

  Future<void> _saveDraft({bool showSnackbar = true}) async {
    if (_isSavingDraft) return;
    if (_currentDraftId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSavingDraft = true;
    });

    try {
      // Prepare ingredients data
      final ingredientsData = _ingredients
          .where((ing) => ing.nameController.text.isNotEmpty)
          .map((ing) => {
                'quantity': double.tryParse(ing.quantityController.text) ?? 0,
                'unit': ing.unit,
                'name': ing.nameController.text,
                'method': ing.method.name,
                'calories': ing.calories,
              })
          .toList();

      // Prepare steps data
      final stepsData = _steps
          .where((step) => step.instructionController.text.isNotEmpty)
          .map((step) => {
                'stepNumber': step.stepNumber,
                'instruction': step.instructionController.text,
                'timerSeconds': step.timerSeconds,
              })
          .toList();

      final draft = RecipeDraft(
        id: _currentDraftId!,
        userId: user.uid,
        title: _titleController.text,
        description: _descriptionController.text,
        coverImagePath: _coverImage?.path,
        serves: int.tryParse(_servesController.text) ?? 1,
        cookTimeSeconds: _getCookTime().inSeconds,
        difficulty: _difficulty.name,
        ingredients: ingredientsData,
        steps: stepsData,
        tags: _selectedTags,
        createdAt: DateTime.now(), // Will be preserved from original
        updatedAt: DateTime.now(),
      );

      await DraftService.saveDraft(draft);
      
      setState(() {
        _lastSaveTime = DateTime.now();
      });

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Draft saved'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      debugPrint('[DRAFT] Draft saved: $_currentDraftId');
    } catch (e) {
      debugPrint('[DRAFT] Error saving draft: $e');
    } finally {
      setState(() {
        _isSavingDraft = false;
      });
    }
  }

  Future<void> _deleteDraft() async {
    if (_currentDraftId == null) return;
    
    try {
      await DraftService.deleteDraft(_currentDraftId!);
      debugPrint('[DRAFT] Draft deleted: $_currentDraftId');
    } catch (e) {
      debugPrint('[DRAFT] Error deleting draft: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveDraft(showSnackbar: false);
    _titleController.dispose();
    _descriptionController.dispose();
    _servesController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    for (var ing in _ingredients) {
      ing.dispose();
    }
    for (var step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _coverImage = File(image.path);
        });
        
        // Auto-save after image change
        _scheduleAutoSave();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Cover image added'),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to pick image')),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickStepImage(int stepIndex) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _steps[stepIndex].imageFile = File(image.path);
        });
        _scheduleAutoSave();
      }
    } catch (e) {
      debugPrint('Error picking step image: $e');
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(IngredientInput());
    });
    _scheduleAutoSave();
  }

  void _removeIngredient(int index) {
    if (_ingredients.length > 1) {
      setState(() {
        _ingredients[index].dispose();
        _ingredients.removeAt(index);
      });
      _calculateTotalCalories();
      _scheduleAutoSave();
    }
  }

  void _addStep() {
    setState(() {
      _steps.add(StepInput(stepNumber: _steps.length + 1));
    });
    _scheduleAutoSave();
  }

  void _removeStep(int index) {
    if (_steps.length > 1) {
      setState(() {
        _steps[index].dispose();
        _steps.removeAt(index);
        for (int i = 0; i < _steps.length; i++) {
          _steps[i].stepNumber = i + 1;
        }
      });
      _scheduleAutoSave();
    }
  }

  Future<void> _calculateTotalCalories() async {
    setState(() {
      _isCalculatingCalories = true;
    });

    int total = 0;
    
    for (var ing in _ingredients) {
      ing.errorMessage = null;
      
      if (ing.nameController.text.isNotEmpty &&
          ing.quantityController.text.isNotEmpty) {
        try {
          final quantity = double.tryParse(ing.quantityController.text);
          if (quantity == null || quantity <= 0) {
            ing.errorMessage = 'Invalid quantity';
            continue;
          }

          final calories = await _calorieService.calculateCalories(
            ingredientName: ing.nameController.text,
            quantity: quantity,
            unit: ing.unit,
            cookingMethod: ing.method,
          );
          ing.calories = calories;
          total += calories;
        } catch (e) {
          ing.errorMessage = 'Could not calculate';
        }
      }
    }
    
    setState(() {
      _totalCalories = total;
      _isCalculatingCalories = false;
    });
  }

  Duration _getCookTime() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  Future<void> _createRecipe() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_coverImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a cover image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final validIngredients = _ingredients.where(
      (ing) => ing.nameController.text.isNotEmpty && 
                ing.quantityController.text.isNotEmpty
    ).toList();

    if (validIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one ingredient'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final validSteps = _steps.where(
      (step) => step.instructionController.text.isNotEmpty
    ).toList();

    if (validSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one step'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    
    try {
      final ingredients = validIngredients
          .map((ing) => Ingredient(
                quantity: double.parse(ing.quantityController.text),
                unit: ing.unit,
                name: ing.nameController.text,
                method: ing.method,
                calories: ing.calories,
              ))
          .toList();

      final steps = validSteps
          .map((step) => RecipeStep(
                stepNumber: step.stepNumber,
                instruction: step.instructionController.text,
                imageFile: step.imageFile,
                timer: step.timerSeconds > 0
                    ? Duration(seconds: step.timerSeconds)
                    : null,
              ))
          .toList();

      await recipeProvider.createRecipe(
        title: _titleController.text,
        description: _descriptionController.text,
        coverImage: _coverImage!,
        serves: int.parse(_servesController.text),
        cookTime: _getCookTime(),
        difficulty: _difficulty,
        ingredients: ingredients,
        steps: steps,
        tags: _selectedTags,
        totalCalories: _totalCalories,
      );

      // Delete draft after successful publish
      await _deleteDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Recipe created successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Failed to Create Recipe'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          children: [
            const Text(
              'Create Recipe',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_lastSaveTime != null)
              Text(
                'Saved ${_getTimeAgo(_lastSaveTime!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Save Draft Button
          IconButton(
            icon: _isSavingDraft
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.save, color: AppColors.primary),
            onPressed: () => _saveDraft(showSnackbar: true),
            tooltip: 'Save Draft',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Draft indicator
              if (_currentDraftId != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drafts, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Auto-saving as draft every 3 seconds',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Cover Image
              Center(child: _buildCoverImagePicker()),
              const SizedBox(height: 24),

              // Title
              _buildTextField(
                controller: _titleController,
                hintText: 'Recipe Title',
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              _buildTextField(
                controller: _descriptionController,
                hintText: 'Description',
                maxLines: 3,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Serves, Cook Time, Difficulty
              _buildServesInput(),
              const SizedBox(height: 16),
              _buildCookTimeInput(),
              const SizedBox(height: 16),
              _buildDifficultyDropdown(),
              const SizedBox(height: 32),

              // Ingredients Section
              _buildIngredientsSection(),
              const SizedBox(height: 32),

              // Steps Section
              _buildStepsSection(),
              const SizedBox(height: 32),

              // Tags Section
              _buildTagsSection(),
              const SizedBox(height: 32),

              // Create Button
              Consumer<RecipeProvider>(
                builder: (context, provider, _) {
                  return CustomButton(
                    text: 'Publish Recipe',
                    onPressed: _createRecipe,
                    isLoading: provider.isLoading,
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildCoverImagePicker() {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[50],
        ),
        child: _coverImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  _coverImage!,
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Add Cover Photo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to upload',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 16),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: validator,
    );
  }

  Widget _buildServesInput() {
    return Row(
      children: [
        const Icon(Icons.people_outline, size: 22),
        const SizedBox(width: 12),
        const Text(
          'Serves',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        SizedBox(
          width: 100,
          child: TextFormField(
            controller: _servesController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixText: 'people',
              suffixStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v?.isEmpty ?? true) return 'Required';
              final num = int.tryParse(v!);
              if (num == null || num < 1) return 'Min 1';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCookTimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 22),
            const SizedBox(width: 12),
            const Text(
              'Cook Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeField(_hoursController, 'HH', 'hrs'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildTimeField(_minutesController, 'MM', 'min'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildTimeField(_secondsController, 'SS', 'sec'),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeField(TextEditingController controller, String hint, String suffix) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14),
          suffixText: suffix,
          suffixStyle: TextStyle(fontSize: 10, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _TimeInputFormatter(maxValue: hint == 'HH' ? 23 : 59),
        ],
      ),
    );
  }

  Widget _buildDifficultyDropdown() {
    return Row(
      children: [
        const Icon(Icons.bar_chart, size: 22),
        const SizedBox(width: 12),
        const Text(
          'Difficulty',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<Difficulty>(
            value: _difficulty,
            underline: const SizedBox(),
            style: const TextStyle(
              fontSize: 15, 
              color: Colors.black, 
              fontWeight: FontWeight.w500
            ),
            items: Difficulty.values.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(d.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _difficulty = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_isCalculatingCalories)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        ..._ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ing = entry.value;
          return _buildIngredientRow(ing, index);
        }).toList(),
        
        const SizedBox(height: 12),
        
        TextButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add_circle_outline, size: 22),
          label: const Text('Add Ingredient', style: TextStyle(fontSize: 16)),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        
        const SizedBox(height: 16),
        
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'TOTAL: $_totalCalories kcal',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(IngredientInput ing, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ing.errorMessage != null ? AppColors.error : Colors.grey[200]!,
          width: ing.errorMessage != null ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Drag Handle
              Icon(Icons.drag_indicator, color: Colors.grey[400], size: 24),
              const SizedBox(width: 8),
              
              // Quantity
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: ing.quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Quantity',
                          hintStyle: const TextStyle(fontSize: 16),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        onChanged: (_) => _calculateTotalCalories(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Unit Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButton<String>(
                        value: ing.unit,
                        underline: const SizedBox(),
                        isDense: true,
                        style: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.w500),
                        items: ['g', 'kg', 'cup', 'tbsp', 'tsp', 'ml', 'L']
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              ing.unit = value;
                            });
                            _calculateTotalCalories();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // Remove button
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error, size: 22),
                onPressed: () => _removeIngredient(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ingredient Name with Autocomplete
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return _commonIngredients.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              ing.nameController.text = selection;
              _calculateTotalCalories();
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              ing.nameController.text = controller.text;
              controller.addListener(() {
                ing.nameController.text = controller.text;
              });
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Ingredient Name',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  prefixIcon: const Icon(Icons.search, size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                onChanged: (_) => _calculateTotalCalories(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    width: MediaQuery.of(context).size.width - 80,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: options.length,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(
                            option,
                            style: const TextStyle(fontSize: 16),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),

          Row(
            children: [
              // Cooking Method
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<CookingMethod>(
                    value: ing.method,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.w600),
                    items: CookingMethod.values.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          ing.method = value;
                        });
                        _calculateTotalCalories();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Calories Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${ing.calories} kcal',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          
          // Error message
          if (ing.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ing.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Steps',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ..._steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return _buildStepItem(step, index);
        }).toList(),
        
        const SizedBox(height: 12),
        
        TextButton.icon(
          onPressed: _addStep,
          icon: const Icon(Icons.add_circle_outline, size: 22),
          label: const Text('Add Step', style: TextStyle(fontSize: 16)),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildStepItem(StepInput step, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Drag Handle
              Icon(Icons.drag_indicator, color: Colors.grey[400], size: 24),
              const SizedBox(width: 8),
              
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => _removeStep(index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Instruction
          TextFormField(
            controller: step.instructionController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Step ${step.stepNumber} instruction...',
              hintStyle: const TextStyle(fontSize: 16),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Image Picker
          if (step.imageFile != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    step.imageFile!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () {
                        setState(() {
                          step.imageFile = null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () => _pickStepImage(index),
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Step Image (Optional)', style: TextStyle(fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Timer with Seconds
          Row(
            children: [
              const Icon(Icons.timer, size: 20),
              const SizedBox(width: 8),
              const Text('Timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              _buildStepTimeField(step.hoursController, 'HH', 'hrs'),
              const Text(' : ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildStepTimeField(step.minutesController, 'MM', 'min'),
              const Text(' : ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildStepTimeField(step.secondsController, 'SS', 'sec'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepTimeField(TextEditingController controller, String hint, String suffix) {
    return SizedBox(
      width: 65,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 16),
          suffixText: suffix,
          suffixStyle: TextStyle(fontSize: 10, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _TimeInputFormatter(maxValue: hint == 'HH' ? 23 : 59),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_offer, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag, style: const TextStyle(fontSize: 15)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 15,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Helper Classes
class IngredientInput {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  String unit = 'g';
  CookingMethod method = CookingMethod.raw;
  int calories = 0;
  String? errorMessage;

  void dispose() {
    quantityController.dispose();
    nameController.dispose();
  }
}

class StepInput {
  int stepNumber;
  final TextEditingController instructionController = TextEditingController();
  final TextEditingController hoursController = TextEditingController(text: '00');
  final TextEditingController minutesController = TextEditingController(text: '00');
  final TextEditingController secondsController = TextEditingController(text: '00');
  File? imageFile;
  
  int get timerSeconds {
    final hours = int.tryParse(hoursController.text) ?? 0;
    final minutes = int.tryParse(minutesController.text) ?? 0;
    final seconds = int.tryParse(secondsController.text) ?? 0;
    return (hours * 3600) + (minutes * 60) + seconds;
  }

  StepInput({required this.stepNumber});

  void dispose() {
    instructionController.dispose();
    hoursController.dispose();
    minutesController.dispose();
    secondsController.dispose();
  }
}

// Time Input Formatter
class _TimeInputFormatter extends TextInputFormatter {
  final int maxValue;
  
  _TimeInputFormatter({required this.maxValue});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final int value = int.tryParse(newValue.text) ?? 0;
    if (value > maxValue) {
      return oldValue;
    }
    return newValue;
  }
}