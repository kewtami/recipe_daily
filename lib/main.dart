import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:recipe_daily/firebase_options.dart';
import 'package:recipe_daily/presentation/providers/recipe_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'package:recipe_daily/presentation/providers/interaction_provider.dart';
import 'package:recipe_daily/presentation/providers/collection_provider.dart';
import 'presentation/screens/auth/auth_wrapper.dart';
import 'core/constants/app_colors.dart';
import 'core/services/calorie_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  };

  // Initialize Calorie Service
  print('Initializing CalorieService...');
  await CalorieService().initialize();
  print('CalorieService initialized');

  runApp(const RecipeDailyApp());
}

class RecipeDailyApp extends StatelessWidget {
  const RecipeDailyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => InteractionProvider()),
        ChangeNotifierProvider(create: (_) => CollectionProvider()),
      ],
      child: MaterialApp(
        title: 'Recipe Daily',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}