import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/services/auth_provider.dart';
import '../../core/models/user_model.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'user_not_found_screen.dart';
import '../temple/temple_dashboard.dart';
import '../priest/priest_dashboard.dart';
import '../user/user_home.dart';
import '../../widgets/offline_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const List<_DemoAccount> _demoAccounts = [
    _DemoAccount(
      label: 'Devotee Demo',
      email: 'muthu@gmail.com',
      password: '123456',
      role: 'User',
      icon: Icons.volunteer_activism,
    ),
    _DemoAccount(
      label: 'Temple Demo',
      email: 'meenakshi_admin@gmail.com',
      password: '123456',
      role: 'Temple',
      icon: Icons.account_balance,
    ),
    _DemoAccount(
      label: 'Priest Demo',
      email: 'prassana@gmail.com',
      password: '123456',
      role: 'Priest',
      icon: Icons.workspace_premium,
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      final role = auth.currentUser?.role;
      if (role == UserRole.temple) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TempleDashboard()),
        );
      } else if (role == UserRole.priest) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PriestDashboard()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserHome()),
        );
      }
    } else if (mounted && auth.profileMissing) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UserNotFoundScreen(email: _emailController.text.trim()),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Authentication failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _fillDemoCredentials(_DemoAccount account) {
    setState(() {
      _emailController.text = account.email;
      _passwordController.text = account.password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Divine Gopuram header
                    ClipPath(
                      clipper: TempleArchClipper(),
                      child: Container(
                        height: 250,
                        width: double.infinity,
                        color: DivineTheme.maroon,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wb_sunny,
                              color: DivineTheme.gold,
                              size: 64,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'SEVA',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: DivineTheme.gold,
                                    letterSpacing: 4,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Connect with the Divine',
                              style: TextStyle(
                                color: DivineTheme.creamDark,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: DivineTheme.gold.withValues(alpha: 0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: DivineTheme.creamDark,
                                  child: Icon(Icons.auto_awesome, color: DivineTheme.maroon, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Free-tier demo stack',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: DivineTheme.textDark,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Firebase Auth + RTDB + Cloudinary + Jitsi Meet',
                                        style: TextStyle(color: DivineTheme.textLight, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _demoAccounts
                                  .map(
                                    (account) => ActionChip(
                                      avatar: Icon(account.icon, size: 16, color: DivineTheme.maroon),
                                      label: Text(account.label),
                                      backgroundColor: DivineTheme.creamDark.withValues(alpha: 0.55),
                                      side: BorderSide(color: DivineTheme.gold.withValues(alpha: 0.35)),
                                      onPressed: () => _fillDemoCredentials(account),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tap a role above to autofill login and jump into the live demo flow.',
                              style: TextStyle(fontSize: 12, color: DivineTheme.textLight, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome Back',
                              style: Theme.of(context).textTheme.displayMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email, color: DivineTheme.maroon),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return 'Enter a valid email';
                                if (!value.endsWith('@gmail.com')) return 'Use a Gmail address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock, color: DivineTheme.maroon),
                              ),
                              obscureText: true,
                              validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                  );
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: DivineTheme.saffron, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return auth.isLoading
                                    ? const Center(child: CircularProgressIndicator(color: DivineTheme.maroon))
                                    : ElevatedButton(
                                        onPressed: _login,
                                        style: ElevatedButton.styleFrom(
                                          elevation: 4,
                                          shadowColor: DivineTheme.saffron.withOpacity(0.4),
                                        ),
                                        child: const Text('SIGN IN'),
                                      );
                              },
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('New to Seva? '),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      color: DivineTheme.saffron,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAccount {
  final String label;
  final String email;
  final String password;
  final String role;
  final IconData icon;

  const _DemoAccount({
    required this.label,
    required this.email,
    required this.password,
    required this.role,
    required this.icon,
  });
}
