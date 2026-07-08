import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seva/core/services/app_provider.dart';
import 'package:seva/core/services/auth_provider.dart';
import 'package:seva/core/services/firebase_service.dart';
import 'package:seva/features/auth/login_screen.dart';
import 'package:seva/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  HttpOverrides.global = MockHttpOverrides();

  setUp(() async {
    await FirebaseService().clearSession();
  });

  Future<void> enterTextByLabel(WidgetTester tester, String label, String value) async {
    final labelFinder = find.text(label);
    final fieldFinder = find.ancestor(of: labelFinder, matching: find.byType(TextFormField));

    expect(fieldFinder, findsOneWidget, reason: 'Could not find field with label "$label"');
    await tester.enterText(fieldFinder.first, value);
    await tester.pump();
  }

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MaterialApp(home: AuthWrapper()),
    );
  }

  Future<void> completeSignup(
    WidgetTester tester, {
    required String name,
    required String phone,
    required String email,
    required String password,
    required String securityAnswer,
    required String roleLabel,
  }) async {
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);

    await enterTextByLabel(tester, 'Full Name', name);
    await enterTextByLabel(tester, 'Phone Number', phone);
    await enterTextByLabel(tester, 'Email Address', email);
    await enterTextByLabel(tester, 'Password', password);
    await enterTextByLabel(tester, 'Security Answer', securityAnswer);

    if (roleLabel != 'Devotee (User)') {
      await tester.tap(find.text(roleLabel));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('Signup routing smoke tests', () {
    testWidgets('Devotee signup lands on UserHome', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await completeSignup(
        tester,
        name: 'Muthu Devotee',
        phone: '9876543222',
        email: 'muthu_route_test@gmail.com',
        password: '123456',
        securityAnswer: 'Madurai',
        roleLabel: 'Devotee (User)',
      );

      expect(find.text('Social Wall'), findsWidgets);
      expect(find.byType(LoginScreen), findsNothing);

      final currentUser = await FirebaseService().getCurrentUser();
      expect(currentUser?.name, 'Muthu Devotee');
      expect(currentUser?.role.name, 'user');
    });

    testWidgets('Temple signup lands on TempleDashboard', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await completeSignup(
        tester,
        name: 'Seva Temple Test',
        phone: '9876543233',
        email: 'temple_route_test@gmail.com',
        password: '123456',
        securityAnswer: 'Karpaka',
        roleLabel: 'Temple Admin',
      );

      expect(find.text('Temple Analytics'), findsOneWidget);
      expect(find.text('Seva Temple Test'), findsWidgets);

      final currentUser = await FirebaseService().getCurrentUser();
      expect(currentUser?.name, 'Seva Temple Test');
      expect(currentUser?.role.name, 'temple');
    });

    testWidgets('Priest signup lands on PriestDashboard', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await completeSignup(
        tester,
        name: 'Arun Gurukkal Route',
        phone: '9876543244',
        email: 'priest_route_test@gmail.com',
        password: '123456',
        securityAnswer: 'Madurai',
        roleLabel: 'Priest',
      );

      expect(find.text('Priest Bookings'), findsOneWidget);

      final currentUser = await FirebaseService().getCurrentUser();
      expect(currentUser?.name, 'Arun Gurukkal Route');
      expect(currentUser?.role.name, 'priest');
    });
  });
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => MockHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static const List<int> _transparentImage = [
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, 0x02, 0x02, 0x4c, 0x01, 0x00, 0x3b
  ];

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
