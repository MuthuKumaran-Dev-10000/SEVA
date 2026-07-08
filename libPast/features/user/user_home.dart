import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/models/user_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/priest_model.dart';
import '../../core/models/temple_model.dart';
import '../../core/models/service_model.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/app_provider.dart';
import '../../core/services/pdf_service.dart';
import '../auth/login_screen.dart';
import 'temple_detail_screen.dart';
import 'cart_screen.dart';
import 'family_profiles_tab.dart';
import 'social_feed_tab.dart';
import 'meet_screen_stub.dart';
import '../../widgets/offline_banner.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String _exploreMode = 'Temples'; // 'Temples' or 'Priests'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final app = Provider.of<AppProvider>(context, listen: false);
      if (auth.currentUser != null) {
        app.listenAllGlobalData();
        app.listenUserSessions(auth.currentUser!.uid, UserRole.user);
      }
    });
  }

  void _launchJitsi(String urlStr) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => getInAppMeetScreen(urlStr),
      ),
    );
  }

  Future<void> _downloadReceipt(OrderModel order) async {
    try {
      final bytes = await PdfService.generateReceiptBytes(order);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt generated: ${bytes.length} bytes'),
            action: SnackBarAction(
              label: 'OK',
              textColor: DivineTheme.gold,
              onPressed: () {},
            ),
            backgroundColor: DivineTheme.maroon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF receipt: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSlotPickerSheet(BuildContext context, AppProvider app, ServiceModel s) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String searchQuery = '';
    String? selectedSlot;

    final List<String> standardSlots = [
      "07:00 AM", "08:00 AM", "09:00 AM", "10:00 AM", "11:00 AM",
      "12:00 PM", "04:00 PM", "05:00 PM", "06:00 PM", "07:00 PM", "08:00 PM"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final dateStr = selectedDate.toString().split(' ')[0];
            
            // Filter slots by search query
            final filteredSlots = standardSlots.where((slot) {
              return slot.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Date & Time Slot',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DivineTheme.maroon, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    s.name,
                    style: const TextStyle(color: DivineTheme.textLight, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date selection row (horizontal)
                  const Text('Select Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index + 1));
                        final isSelected = date.year == selectedDate.year &&
                            date.month == selectedDate.month &&
                            date.day == selectedDate.day;
                        
                        // Format weekday name and day number
                        final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final weekdayStr = weekdays[date.weekday - 1];
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: ChoiceChip(
                            label: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(weekdayStr, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : DivineTheme.textLight, fontWeight: FontWeight.w600)),
                                Text('${date.day}', style: TextStyle(fontSize: 14, color: isSelected ? Colors.white : DivineTheme.textDark, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: DivineTheme.maroon,
                            backgroundColor: DivineTheme.creamDark.withOpacity(0.3),
                            onSelected: (selected) {
                              if (selected) {
                                setStateSheet(() {
                                  selectedDate = date;
                                  selectedSlot = null; // reset slot selection
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Slot search input
                  TextField(
                    onChanged: (val) {
                      setStateSheet(() {
                        searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search times (e.g. morning, PM, 09)...',
                      prefixIcon: Icon(Icons.search, color: DivineTheme.maroon, size: 20),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Slots grid
                  const Text('Select Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredSlots.isEmpty
                        ? const Center(child: Text('No slots match your search.', style: TextStyle(color: DivineTheme.textLight)))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: filteredSlots.length,
                            itemBuilder: (context, index) {
                              final slot = filteredSlots[index];
                              
                              // Check if slot is already booked in real-time
                              final isBooked = app.orders.any((o) =>
                                  o.serviceId == s.id &&
                                  o.bookingDate == dateStr &&
                                  o.bookingTime == slot &&
                                  o.status != 'cancelled' &&
                                  o.status != 'declined');

                              final isSelected = selectedSlot == slot;

                              return InkWell(
                                onTap: isBooked
                                    ? null
                                    : () {
                                        setStateSheet(() {
                                          selectedSlot = slot;
                                        });
                                      },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isBooked
                                        ? Colors.grey.shade100
                                        : (isSelected ? DivineTheme.saffron.withOpacity(0.15) : Colors.white),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isBooked
                                          ? Colors.grey.shade300
                                          : (isSelected ? DivineTheme.saffron : Colors.grey.shade300),
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          slot,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isBooked
                                                ? Colors.grey.shade400
                                                : (isSelected ? DivineTheme.saffron : DivineTheme.textDark),
                                          ),
                                        ),
                                        if (isBooked)
                                          const Text(
                                            'Booked',
                                            style: TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSlot == null
                          ? null
                          : () {
                              app.addToCart(s, dateStr, selectedSlot!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${s.name} to cart for $dateStr @ ${selectedSlot!}'),
                                  backgroundColor: DivineTheme.maroon,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DivineTheme.maroon,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('CONFIRM SLOT & ADD', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  void _showPriestDetailsSheet(BuildContext context, AppProvider app, PriestModel priest) {
    // Filter private services of this priest
    final priestServices = app.services.where((s) => s.priestId == priest.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: priest.photo.isNotEmpty ? NetworkImage(priest.photo) : null,
                        child: priest.photo.isEmpty ? const Icon(Icons.person, size: 30) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(priest.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
                            Text('Exp: ${priest.experience} • ${priest.address}', style: const TextStyle(fontSize: 12, color: DivineTheme.textLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('About Priest:', style: TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
                  Text(priest.bio.isEmpty ? 'Spiritual Priest assisting in all family prayers.' : priest.bio, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Text('Astrological details: ${priest.rasi} / ${priest.nakshatra} (Lagnam: ${priest.lagnam})', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  const Text('Direct Booking Pujas:', style: TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
                  const SizedBox(height: 8),
                  priestServices.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: Text('No private pujas offered currently.', style: TextStyle(color: DivineTheme.textLight))),
                        )
                      : Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: priestServices.length,
                            itemBuilder: (context, index) {
                              final s = priestServices[index];
                              final isInCart = app.cart.any((item) => item.service.id == s.id);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('₹${s.amount} • ${s.description}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: isInCart
                                    ? IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () {
                                          app.removeFromCartByService(s);
                                          setSheetState(() {});
                                          setState(() {}); // refresh home cart badge
                                        },
                                      )
                                    : ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(); // Close priest details sheet
                                          _showSlotPickerSheet(context, app, s);
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon, visualDensity: VisualDensity.compact),
                                        child: const Text('ADD'),
                                      ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final app = Provider.of<AppProvider>(context);

    if (auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: DivineTheme.maroon),
        ),
      );
    }

    final filteredTemples = app.temples.where((t) {
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.address.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredPriests = app.priests.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.rasi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.nakshatra.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final tabs = [
      const SocialFeedTab(),
      _buildExploreTab(context, app, filteredTemples, filteredPriests),
      _buildBookingsTab(context, app),
      const FamilyProfilesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_currentIndex == 1)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                ),
                if (app.cart.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: DivineTheme.saffron,
                      child: Text(
                        '${app.cart.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          _searchQuery = ''; // clear query
        }),
        selectedItemColor: DivineTheme.maroon,
        unselectedItemColor: DivineTheme.textLight,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Social Wall'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_stories), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.family_restroom), label: 'Family'),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Social Wall';
      case 1:
        return 'SevaSetu';
      case 2:
        return 'My Bookings';
      case 3:
        return 'My Family Roster';
      default:
        return 'SevaSetu';
    }
  }

  // --- TAB 1: EXPLORE (TEMPLES / PRIESTS TOGGLE) ---
  Widget _buildExploreTab(BuildContext context, AppProvider app, List<TempleModel> templeList, List<PriestModel> priestList) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: const BoxDecoration(
              color: DivineTheme.maroon,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Begin Your Spiritual Journey',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: DivineTheme.gold,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Book verified temple pujas, archanas, and private family priests.',
                  style: TextStyle(color: DivineTheme.creamDark, fontSize: 13),
                ),
                const SizedBox(height: 20),
                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: _exploreMode == 'Temples' 
                        ? 'Search Temples or Locations...' 
                        : 'Search Priests by Name, Rasi, Star...',
                    prefixIcon: const Icon(Icons.search, color: DivineTheme.maroon),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Explore Toggle Segment
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Temples Listing', style: TextStyle(fontWeight: FontWeight.bold))),
                    selected: _exploreMode == 'Temples',
                    selectedColor: DivineTheme.maroon.withOpacity(0.15),
                    onSelected: (selected) {
                      if (selected) setState(() => _exploreMode = 'Temples');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Spiritual Priests', style: TextStyle(fontWeight: FontWeight.bold))),
                    selected: _exploreMode == 'Priests',
                    selectedColor: DivineTheme.saffron.withOpacity(0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _exploreMode = 'Priests');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Temples Listing
          if (_exploreMode == 'Temples') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Verified Temples', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                  Text('${templeList.length} Found', style: const TextStyle(color: DivineTheme.textLight, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            templeList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No temples found matching criteria.', style: TextStyle(color: DivineTheme.textLight)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: templeList.length,
                    itemBuilder: (context, index) {
                      final t = templeList[index];
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => TempleDetailScreen(temple: t)),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                child: Image.network(
                                  t.profileImage.isNotEmpty ? t.profileImage : t.coverImage,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(height: 150, color: DivineTheme.creamDark, child: const Icon(Icons.account_balance, color: DivineTheme.maroon, size: 64)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () async {
                                        final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${t.name} ${t.address}")}';
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not launch maps link.')),
                                            );
                                          }
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: DivineTheme.saffron),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              t.address,
                                              style: const TextStyle(
                                                color: DivineTheme.maroon,
                                                fontSize: 13,
                                                decoration: TextDecoration.underline,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ] else ...[
            // Priests Listing
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Spiritual Priests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                  Text('${priestList.length} Found', style: const TextStyle(color: DivineTheme.textLight, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            priestList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No spiritual priests found.', style: TextStyle(color: DivineTheme.textLight)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: priestList.length,
                    itemBuilder: (context, index) {
                      final p = priestList[index];
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundImage: p.photo.isNotEmpty ? NetworkImage(p.photo) : null,
                            backgroundColor: DivineTheme.gold,
                            child: p.photo.isEmpty ? const Icon(Icons.person, color: DivineTheme.maroon) : null,
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Experience: ${p.experience} • Rasi: ${p.rasi}', style: const TextStyle(fontSize: 13, color: DivineTheme.textDark)),
                              Text('Star (Nakshatra): ${p.nakshatra}', style: const TextStyle(fontSize: 12, color: DivineTheme.textLight)),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showPriestDetailsSheet(context, app, p),
                            style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron, visualDensity: VisualDensity.compact),
                            child: const Text('BOOK'),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ],
      ),
    );
  }

  // --- TAB 2: MY BOOKINGS ---
  Widget _buildBookingsTab(BuildContext context, AppProvider app) {
    if (app.orders.isEmpty) {
      return const Center(child: Text('You have not booked any services yet.', style: TextStyle(color: DivineTheme.textLight)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: app.orders.length,
      itemBuilder: (context, index) {
        final o = app.orders[index];
        return _BookingCard(
          order: o,
          app: app,
          onDownloadReceipt: _downloadReceipt,
          onLaunchJitsi: _launchJitsi,
        );
      },
    );
  }
}

class _BookingCard extends StatefulWidget {
  final OrderModel order;
  final AppProvider app;
  final Function(OrderModel) onDownloadReceipt;
  final Function(String) onLaunchJitsi;

  const _BookingCard({
    required this.order,
    required this.app,
    required this.onDownloadReceipt,
    required this.onLaunchJitsi,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _isExpanded = false;

  void _showRescheduleSheet(BuildContext context) {
    final app = widget.app;
    final order = widget.order;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String searchQuery = '';
    String? selectedSlot;

    final List<String> standardSlots = [
      "07:00 AM", "08:00 AM", "09:00 AM", "10:00 AM", "11:00 AM",
      "12:00 PM", "04:00 PM", "05:00 PM", "06:00 PM", "07:00 PM", "08:00 PM"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final dateStr = selectedDate.toString().split(' ')[0];
            
            // Filter slots by search query
            final filteredSlots = standardSlots.where((slot) {
              return slot.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reschedule Service Slot',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DivineTheme.maroon, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    order.serviceName,
                    style: const TextStyle(color: DivineTheme.textLight, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date selection row (horizontal)
                  const Text('Select Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index + 1));
                        final isSelected = date.year == selectedDate.year &&
                            date.month == selectedDate.month &&
                            date.day == selectedDate.day;
                        
                        // Format weekday name and day number
                        final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final weekdayStr = weekdays[date.weekday - 1];
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: ChoiceChip(
                            label: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(weekdayStr, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : DivineTheme.textLight, fontWeight: FontWeight.w600)),
                                Text('${date.day}', style: TextStyle(fontSize: 14, color: isSelected ? Colors.white : DivineTheme.textDark, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: DivineTheme.maroon,
                            backgroundColor: DivineTheme.creamDark.withOpacity(0.3),
                            onSelected: (selected) {
                              if (selected) {
                                setStateSheet(() {
                                  selectedDate = date;
                                  selectedSlot = null; // reset slot selection
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Slot search input
                  TextField(
                    onChanged: (val) {
                      setStateSheet(() {
                        searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search times (e.g. morning, PM, 09)...',
                      prefixIcon: Icon(Icons.search, color: DivineTheme.maroon, size: 20),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Slots grid
                  const Text('Select Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredSlots.isEmpty
                        ? const Center(child: Text('No slots match your search.', style: TextStyle(color: DivineTheme.textLight)))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: filteredSlots.length,
                            itemBuilder: (context, index) {
                              final slot = filteredSlots[index];
                              
                              // Check if slot is already booked in real-time, EXCLUDING this order itself
                              final isBooked = app.orders.any((o) =>
                                  o.id != order.id &&
                                  o.serviceId == order.serviceId &&
                                  o.bookingDate == dateStr &&
                                  o.bookingTime == slot &&
                                  o.status != 'cancelled' &&
                                  o.status != 'declined');

                              final isSelected = selectedSlot == slot;

                              return InkWell(
                                onTap: isBooked
                                    ? null
                                    : () {
                                        setStateSheet(() {
                                          selectedSlot = slot;
                                        });
                                      },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isBooked
                                        ? Colors.grey.shade100
                                        : (isSelected ? DivineTheme.saffron.withOpacity(0.15) : Colors.white),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isBooked
                                          ? Colors.grey.shade300
                                          : (isSelected ? DivineTheme.saffron : Colors.grey.shade300),
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          slot,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isBooked
                                                ? Colors.grey.shade400
                                                : (isSelected ? DivineTheme.saffron : DivineTheme.textDark),
                                          ),
                                        ),
                                        if (isBooked)
                                          const Text(
                                            'Booked',
                                            style: TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSlot == null
                          ? null
                          : () async {
                              final updatedOrder = order.copyWith(
                                bookingDate: dateStr,
                                bookingTime: selectedSlot!,
                              );
                              await app.updateOrderDetails(updatedOrder);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Rescheduled ${order.serviceName} to $dateStr @ ${selectedSlot!}'),
                                    backgroundColor: DivineTheme.maroon,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DivineTheme.maroon,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('CONFIRM NEW SLOT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _getBookingDateTime(OrderModel order) {
    try {
      final parts = order.bookingDate.split('-');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final timeParts = order.bookingTime.split(' ');
      if (timeParts.length != 2) return null;
      final hm = timeParts[0].split(':');
      if (hm.length != 2) return null;
      
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      final isPM = timeParts[1].toUpperCase() == 'PM';
      
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  void _confirmCancelBooking(BuildContext context) {
    final bookingDateTime = _getBookingDateTime(widget.order);
    double refundPercentage = 1.0;
    String refundText = "100% Refund (More than 24h prior)";
    
    if (bookingDateTime != null) {
      final now = DateTime.now();
      final difference = bookingDateTime.difference(now);
      final hoursRemaining = difference.inHours;
      
      if (hoursRemaining >= 24) {
        refundPercentage = 1.0;
        refundText = "100% Refund (More than 24h prior)";
      } else if (hoursRemaining >= 12) {
        refundPercentage = 0.5;
        refundText = "50% Refund (Between 12h and 24h prior)";
      } else {
        refundPercentage = 0.0;
        refundText = "0% Refund (Less than 12h prior)";
      }
    }

    final refundAmount = widget.order.amount * refundPercentage;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
            const SizedBox(height: 16),
            const Text('Refund Estimation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
            const SizedBox(height: 4),
            Text(refundText, style: const TextStyle(fontSize: 12, color: DivineTheme.maroon, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Estimated Refund: ₹${refundAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('NO', style: TextStyle(color: DivineTheme.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final updated = widget.order.copyWith(status: 'cancelled');
              await widget.app.updateOrderDetails(updated);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Booking cancelled. Estimated refund of ₹${refundAmount.toStringAsFixed(2)} initiated.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isPrivate = o.templeId.isEmpty;
    final canModify = o.status == 'pending' || o.status == 'accepted';

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      o.serviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.maroon),
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusChip(o.status),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: DivineTheme.textLight,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isPrivate ? 'Type: Private Booking' : 'Temple: ${o.templeName}',
                style: TextStyle(color: isPrivate ? DivineTheme.saffron : DivineTheme.textLight, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: ${o.bookingDate}', style: const TextStyle(fontSize: 13)),
                  Text('Time: ${o.bookingTime}', style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paid: ₹${o.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text(
                    o.assignedPriestName.isEmpty ? 'Priest: Temple Assigned' : 'Priest: ${o.assignedPriestName}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text('Booking ID: ${o.id}', style: const TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                Text('Payment Reference: ${o.paymentReference}', style: const TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                Text('Jitsi Link: ${o.jitsiLink}', style: const TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                if (canModify) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmCancelBooking(context),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('CANCEL'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRescheduleSheet(context),
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('RESCHEDULE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DivineTheme.saffron,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onDownloadReceipt(o),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('RECEIPT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DivineTheme.maroon,
                        side: const BorderSide(color: DivineTheme.maroon),
                      ),
                    ),
                  ),
                  if (o.status == 'accepted' || o.status == 'live_ready') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: o.status == 'live_ready' ? () => widget.onLaunchJitsi(o.jitsiLink) : null,
                        icon: const Icon(Icons.video_call),
                        label: Text(o.status == 'live_ready' ? 'JOIN NOW' : 'WAITING'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DivineTheme.saffron,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'accepted' || status == 'assigned') color = Colors.blue;
    if (status == 'completed') color = Colors.green;
    if (status == 'declined' || status == 'cancelled') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
