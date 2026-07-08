import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/booking_flow_provider.dart';
import '../../core/theme.dart';
import '../auth/login_signup_sheet.dart';
import '../cart/checkout_dialog.dart';
import '../dashboards/priest_dashboard.dart';
import '../dashboards/temple_dashboard.dart';
import 'sidebar.dart';

// Devotee tabs
import '../temple/temples_tab.dart';
import '../service/services_tab.dart';
import '../timing/date_tab.dart';
import '../timing/timings_tab.dart';
import '../booking/bookings_tab.dart';
import '../about/about_tab.dart';
import '../auspicious/auspicious_tab.dart';
import '../video/video_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showConnectionDialog(BuildContext context) {
    final client = Provider.of<ApiClient>(context, listen: false);
    final controller = TextEditingController(text: client.baseUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Server Configuration',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the IP and Port of your server (e.g., 192.168.1.10:8000):',
                style: GoogleFonts.outfit(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.1.10:8000',
                  prefixIcon: Icon(Icons.wifi, color: SevaTheme.primaryMaroon),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.outfit(color: SevaTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final host = controller.text.trim();
                if (host.isNotEmpty) {
                  await client.setBaseUrl(host);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Server base URL set to: ${client.baseUrl}'),
                        backgroundColor: SevaTheme.primaryMaroon,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save & Test'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cart = Provider.of<CartProvider>(context);
    final client = Provider.of<ApiClient>(context);
    final flow = Provider.of<BookingFlowProvider>(context);

    final role = auth.currentUser?['role'] ?? 'devotee';

    // 1. Render Priest Dashboard
    if (auth.isLoggedIn && role == 'priest') {
      return const PriestDashboard();
    }

    // 2. Render Temple Dashboard
    if (auth.isLoggedIn && role == 'temple') {
      return const TempleDashboard();
    }

    // 3. Render Devotee / Guest Guided Funnel Home Screen
    return Scaffold(
      key: _scaffoldKey,
      drawer: auth.isLoggedIn ? const Sidebar() : null,
      appBar: AppBar(
        leading: auth.isLoggedIn
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : Container(
                margin: const EdgeInsets.only(left: 12),
                child: const Icon(Icons.temple_hindu, color: SevaTheme.secondaryGold, size: 28),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEVA',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: SevaTheme.secondaryGold),
            ),
            Text(
              flow.selectedTempleName != null
                  ? 'Booking: ${flow.selectedTempleName}'
                  : 'Divine Temple Bookings',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.white.withOpacity(0.8), letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          // Connection status
          IconButton(
            icon: Icon(
              client.isConnected ? Icons.wifi : Icons.wifi_off,
              color: client.isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
            tooltip: client.isConnected ? 'Connected' : 'Disconnected! Config IP',
            onPressed: () => _showConnectionDialog(context),
          ),
          
          // Cart
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CheckoutDialog(),
                  );
                },
              ),
              if (cart.items.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: SevaTheme.secondaryGold, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cart.items.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 8),

          // User actions / Login button
          auth.isLoggedIn
              ? PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  onSelected: (val) {
                    if (val == 'logout') {
                      auth.logout();
                      flow.resetFlow();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logged out successfully.')),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        auth.currentUser?['full_name'] ?? 'Devotee',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: SevaTheme.secondaryGold.withOpacity(0.3),
                    backgroundImage: auth.currentUser?['avatar_url'] != null && auth.currentUser!['avatar_url'].toString().isNotEmpty
                        ? (auth.currentUser!['avatar_url'].toString().startsWith('http')
                            ? NetworkImage(auth.currentUser!['avatar_url'])
                            : NetworkImage('${client.baseUrl}${auth.currentUser!['avatar_url']}'))
                        : null,
                    child: auth.currentUser?['avatar_url'] == null || auth.currentUser!['avatar_url'].toString().isEmpty
                        ? Text(
                            (auth.currentUser?['full_name'] ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.outfit(color: SevaTheme.primaryMaroon, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const LoginSignupSheet(),
                      );
                    },
                    icon: const Icon(Icons.login, color: SevaTheme.secondaryGold, size: 18),
                    label: Text('Login', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      backgroundColor: SevaTheme.secondaryGold.withOpacity(0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: SevaTheme.secondaryGold),
                      ),
                    ),
                  ),
                ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
                      Tab(text: 'Temples', icon: Icon(Icons.church_outlined, size: 20)),
            Tab(text: 'Services', icon: Icon(Icons.volunteer_activism_outlined, size: 20)),
            Tab(text: 'Date', icon: Icon(Icons.calendar_month_outlined, size: 20)),
            Tab(text: 'Timings', icon: Icon(Icons.access_time_outlined, size: 20)),
            Tab(text: 'Bookings', icon: Icon(Icons.receipt_long_outlined, size: 20)),
            Tab(text: 'About us', icon: Icon(Icons.info_outline, size: 20)),
            Tab(text: 'Auspicious days', icon: Icon(Icons.calendar_today_outlined, size: 20)),
            Tab(text: 'Video', icon: Icon(Icons.video_call_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
                    TemplesTab(tabController: _tabController),
          ServicesTab(tabController: _tabController),
          DateTab(tabController: _tabController),
          TimingsTab(tabController: _tabController),
          const BookingsTab(),
          const AboutTab(),
          const AuspiciousTab(),
          const VideoTab(),
        ],
      ),
    );
  }
}
