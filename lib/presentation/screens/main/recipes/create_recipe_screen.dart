import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:recipe_daily/presentation/screens/main/main_screen.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/recipe_model.dart';
import '../../../../core/services/calorie_service.dart';
import '../../../providers/recipe_provider.dart';
import '../../../widgets/common/custom_button.dart';

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({Key? key}) : super(key: key);

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

  @override
  void dispose() {
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Cover image added successfully'),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to pick image. Please try again')),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('Step ${stepIndex + 1} image added'),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to pick step image')),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(IngredientInput());
    });
  }

  void _removeIngredient(int index) {
    if (_ingredients.length > 1) {
      setState(() {
        _ingredients[index].dispose();
        _ingredients.removeAt(index);
      });
      _calculateTotalCalories();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Recipe must have at least one ingredient'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _addStep() {
    setState(() {
      _steps.add(StepInput(stepNumber: _steps.length + 1));
    });
  }

  void _removeStep(int index) {
    if (_steps.length > 1) {
      setState(() {
        _steps[index].dispose();
        _steps.removeAt(index);
        // Renumber steps
        for (int i = 0; i < _steps.length; i++) {
          _steps[i].stepNumber = i + 1;
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Recipe must have at least one step'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _calculateTotalCalories() async {
    setState(() {
      _isCalculatingCalories = true;
    });

    int total = 0;
    int successCount = 0;
    int errorCount = 0;
    
    // Clear previous errors
    for (var ing in _ingredients) {
      ing.errorMessage = null;
    }
    
    for (var ing in _ingredients) {
      if (ing.nameController.text.isNotEmpty &&
          ing.quantityController.text.isNotEmpty) {
        try {
          final quantity = double.tryParse(ing.quantityController.text);
          if (quantity == null || quantity <= 0) {
            ing.errorMessage = 'Invalid quantity';
            errorCount++;
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
          successCount++;
        } catch (e) {
          errorCount++;
          ing.errorMessage = 'Could not calculate calories';
        }
      }
    }
    
    setState(() {
      _totalCalories = total;
      _isCalculatingCalories = false;
    });
    
    // Show result feedback
    if (mounted) {
      if (errorCount > 0 && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Calculated $successCount ingredients. $errorCount failed',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (errorCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to calculate calories. Check ingredients'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Total: $total kcal calculated'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Please fill all required fields')),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_coverImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please add a cover image'),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate ingredients
    final validIngredients = _ingredients.where(
      (ing) => ing.nameController.text.isNotEmpty && 
                ing.quantityController.text.isNotEmpty
    ).toList();

    if (validIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please add at least one ingredient'),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate steps
    final validSteps = _steps.where(
      (step) => step.instructionController.text.isNotEmpty
    ).toList();

    if (validSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please add at least one step'),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    
    try {
      // Prepare ingredients
      final ingredients = validIngredients
          .map((ing) => Ingredient(
                quantity: double.parse(ing.quantityController.text),
                unit: ing.unit,
                name: ing.nameController.text,
                method: ing.method,
                calories: ing.calories,
              ))
          .toList();

      // Prepare steps with images
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Recipe created successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        ); // Go back to home
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        
        // User-friendly error messages
        if (errorMsg.contains('network') || errorMsg.contains('connection')) {
          errorMsg = 'Network error. Please check your connection and try again';
        } else if (errorMsg.contains('permission') || errorMsg.contains('denied')) {
          errorMsg = 'Storage permission denied. Please allow access in settings';
        } else if (errorMsg.isEmpty) {
          errorMsg = 'Failed to create recipe. Please try again';
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: AppColors.error),
                SizedBox(width: 12),
                Text('Failed to Create Recipe'),
              ],
            ),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _createRecipe(); // Retry
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () {
            // Show confirmation if user has entered data
            if (_titleController.text.isNotEmpty || 
                _descriptionController.text.isNotEmpty ||
                _coverImage != null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard Recipe?'),
                  content: const Text(
                    'You have unsaved changes. Are you sure you want to leave?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close screen
                      },
                      child: const Text(
                        'Discard',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Create Recipe',
          style: TextStyle(
            color: AppColors.secondary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Center(child: _buildCoverImagePicker()),
              const SizedBox(height: 24),

              // Title
              _buildTextField(
                controller: _titleController,
                hintText: 'Recipe Title',
                validator: (v) => v?.isEmpty ?? true ? 'Recipe title is required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              _buildTextField(
                controller: _descriptionController,
                hintText: 'Description',
                maxLines: 3,
                validator: (v) => v?.isEmpty ?? true ? 'Description is required' : null,
              ),
              const SizedBox(height: 24),

              // Serves
              _buildServesInput(),
              const SizedBox(height: 16),

              // Cook Time
              _buildCookTimeInput(),
              const SizedBox(height: 16),

              // Difficulty
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
                    text: 'Create Recipe',
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