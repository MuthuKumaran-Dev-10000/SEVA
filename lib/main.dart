import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/api_client.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/booking_flow_provider.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final apiClient = ApiClient();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ApiClient>.value(value: apiClient),
        ChangeNotifierProxyProvider<ApiClient, AuthProvider>(
          create: (context) => AuthProvider(apiClient),
          update: (context, client, previous) => previous ?? AuthProvider(client),
        ),
        ChangeNotifierProxyProvider<ApiClient, CartProvider>(
          create: (context) => CartProvider(apiClient),
          update: (context, client, previous) => previous ?? CartProvider(client),
        ),
        ChangeNotifierProvider<BookingFlowProvider>(
          create: (context) => BookingFlowProvider(),
        ),
      ],
      child: const SevaApp(),
    ),
  );
}

class SevaApp extends StatelessWidget {
  const SevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seva - Divine Bookings',
      theme: SevaTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
