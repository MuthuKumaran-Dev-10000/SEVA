import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seva/core/services/auth_provider.dart';
import 'package:seva/core/services/app_provider.dart';
import 'package:seva/core/services/firebase_service.dart';
import 'package:seva/features/auth/login_screen.dart';
import 'package:seva/features/priest/priest_dashboard.dart';
import 'package:seva/features/temple/temple_dashboard.dart';
import 'package:seva/features/user/user_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('Login Screen Widget & Validation Tests', () {
    setUp(() async {
      await FirebaseService().clearSession();
    });

    testWidgets('Renders Login Screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify header text exists
      expect(find.text('SEVA'), findsOneWidget);
      expect(find.text('Connect with the Divine'), findsOneWidget);
      
      // Verify textfields exist
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify sign in and signup buttons exist
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Devotee Demo'), findsOneWidget);
      expect(find.text('Temple Demo'), findsOneWidget);
      expect(find.text('Priest Demo'), findsOneWidget);
    });

    testWidgets('Demo autofill chip fills login fields', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Temple Demo'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      expect(
        (tester.widget<TextFormField>(fields.at(0)).controller?.text ?? '').isNotEmpty,
        isTrue,
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller?.text,
        '123456',
      );
    });

    testWidgets('Signing in as temple routes to TempleDashboard', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'meenakshi_admin@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.ensureVisible(find.text('SIGN IN'));
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(find.byType(TempleDashboard), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Signing in as priest routes to PriestDashboard', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'prassana@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.ensureVisible(find.text('SIGN IN'));
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(find.byType(PriestDashboard), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
