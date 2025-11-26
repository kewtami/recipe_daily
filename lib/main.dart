import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:recipe_daily/firebase_options.dart';
import 'package:recipe_daily/presentation/providers/recipe_provider.dart';
import 'package:recipe_daily/presentation/providers/user_provider.dart';
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
  } catch (_) {}

  // Initialize Calorie Service
  await CalorieService().initialize();

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
        ChangeNotifierProvider(create:  (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CollectionProvider()),
      ],
      child: AuthStateListener(
        child: MaterialApp(
          title: 'Recipe Daily',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Montserrat',
          ),
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

/// Listens to authentication state changes and manages InteractionProvider subscriptions
class AuthStateListener extends StatefulWidget {
  final Widget child;

  const AuthStateListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;

      final interactionProvider =
          Provider.of<InteractionProvider>(context, listen: false);
      
      if (user != null) {
        interactionProvider.subscribeToLikedRecipes(user.uid);
        interactionProvider.subscribeToSavedRecipes(user.uid);
      } else {
        interactionProvider.clearCache();
      }
    });

    // Handle initial auth state
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        final interactionProvider =
            Provider.of<InteractionProvider>(context, listen: false);

        interactionProvider.subscribeToLikedRecipes(currentUser.uid);
        interactionProvider.subscribeToSavedRecipes(currentUser.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
