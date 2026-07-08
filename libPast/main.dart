import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/services/auth_provider.dart';
import 'core/services/app_provider.dart';
import 'core/services/seed_data.dart';
import 'core/models/user_model.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/user_not_found_screen.dart';
import 'features/temple/temple_dashboard.dart';
import 'features/priest/priest_dashboard.dart';
import 'features/user/user_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }
  
  // Safe Firebase Initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      if (!kIsWeb) {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
      }
    } catch (dbErr) {
      debugPrint("Failed to set Firebase database persistence: $dbErr");
    }
    // Run DB seeder for live Firebase database
    await runDatabaseSeeding();
  } catch (e) {
    // Firebase not configured yet, falls back to offline/mock mode automatically
    debugPrint("Firebase initialization skipped/failed: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SevaSetu',
      theme: DivineTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: DivineTheme.maroon),
        ),
      );
    }

    if (auth.isAuthenticated && auth.currentUser != null) {
      final role = auth.currentUser!.role;
      if (role == UserRole.temple) {
        return const TempleDashboard();
      } else if (role == UserRole.priest) {
        return const PriestDashboard();
      } else {
        return const UserHome();
      }
    }

    if (auth.profileMissing) {
      return UserNotFoundScreen(email: auth.currentUser?.email ?? '');
    }

    return const LoginScreen();
  }
}
