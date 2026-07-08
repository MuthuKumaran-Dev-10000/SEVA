import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/models/temple_model.dart';
import '../../core/models/service_model.dart';
import '../../core/models/post_model.dart';
import '../../core/models/priest_model.dart';
import '../../core/services/app_provider.dart';
import '../../core/services/auth_provider.dart';
import 'cart_screen.dart';

class TempleDetailScreen extends StatefulWidget {
  final TempleModel temple;
  const TempleDetailScreen({super.key, required this.temple});

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  bool _isFollowing = false;
  final PageController _tourController = PageController();
  int _tourIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = Provider.of<AppProvider>(context, listen: false);
      app.listenAllGlobalData();
      _checkFollowStatus();
    });
  }

  @override
  void dispose() {
    _tourController.dispose();
    super.dispose();
  }

  void _checkFollowStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final app = Provider.of<AppProvider>(context, listen: false);
    if (auth.currentUser != null) {
      final res = await app.isFollowing(auth.currentUser!.uid, widget.temple.id);
      if (mounted) {
        setState(() {
          _isFollowing = res;
        });
      }
    }
  }

  void _toggleFollow() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final app = Provider.of<AppProvider>(context, listen: false);
    if (auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to follow temples.')),
      );
      return;
    }
    await app.toggleFollow(auth.currentUser!.uid, widget.temple.id);
    _checkFollowStatus();
  }

  void _showPujaDetailsSheet(BuildContext context, ServiceModel s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: DivineTheme.maroon,
                                  ),
                                ),
                              ),
                              if (s.isVideoCall) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.videocam, color: DivineTheme.saffron, size: 20),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${s.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (s.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          s.image,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: DivineTheme.creamDark,
                            child: const Icon(Icons.image_not_supported, color: DivineTheme.maroon),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Service Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  s.description,
                  style: const TextStyle(fontSize: 12, color: DivineTheme.textLight, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Puja Guidelines & Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.access_time_filled, 'Duration', s.duration.isNotEmpty ? s.duration : '30 Mins'),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.people_alt, 'Participant Limit', 'Up to ${s.maxParticipants} participants'),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.shopping_bag, 'Items Provided by Temple', 'Pooja plate, Coconut, Flowers, Camphor, Incense, and Prasad'),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.checkroom, 'Suggested Dress Code', 'Traditional wear (Dhoti/Kurta for Men, Saree/Salwar for Women)'),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
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
                            backgroundColor: DivineTheme.creamDark.withValues(alpha: 0.3),
                            onSelected: (selected) {
                              if (selected) {
                                setStateSheet(() {
                                  selectedDate = date;
                                  selectedSlot = null;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
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

                              return FutureBuilder<int>(
                                future: app.getSlotBookingCount(s.id, dateStr, slot),
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  final isFull = count >= s.maxParticipants;
                                  final isSelected = selectedSlot == slot;

                                  return InkWell(
                                    onTap: isFull
                                        ? null
                                        : () {
                                            setStateSheet(() {
                                              selectedSlot = slot;
                                            });
                                          },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isFull
                                            ? Colors.grey.shade100
                                            : (isSelected ? DivineTheme.saffron.withValues(alpha: 0.15) : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isFull
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
                                                color: isFull
                                                    ? Colors.grey.shade400
                                                    : (isSelected ? DivineTheme.saffron : DivineTheme.textDark),
                                              ),
                                            ),
                                            if (isFull)
                                              const Text(
                                                'FULL',
                                                style: TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                              )
                                            else if (count > 0)
                                              Text(
                                                '$count/${s.maxParticipants} Booked',
                                                style: TextStyle(fontSize: 8, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
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
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: DivineTheme.saffron),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: DivineTheme.textLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 12, color: DivineTheme.textDark, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    
    final templeServices = app.services.where((s) => s.templeId == widget.temple.id).toList();
    final templePosts = app.posts.where((p) => p.authorId == widget.temple.id).toList();
    
    // Filter active priests
    final activePriestIds = widget.temple.activePriests.entries
        .where((e) => e.value == 'accepted')
        .map((e) => e.key)
        .toList();
    final templePriests = app.priests.where((p) => activePriestIds.contains(p.id)).toList();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: DivineTheme.maroon,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ElevatedButton.icon(
                      onPressed: _toggleFollow,
                      icon: Icon(
                        _isFollowing ? Icons.check : Icons.add,
                        color: _isFollowing ? DivineTheme.maroon : Colors.white,
                        size: 14,
                      ),
                      label: Text(
                        _isFollowing ? 'FOLLOWING' : 'FOLLOW',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _isFollowing ? DivineTheme.maroon : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.white : DivineTheme.saffron,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _isFollowing ? DivineTheme.maroon : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    widget.temple.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.temple.profileImage.isNotEmpty ? widget.temple.profileImage : widget.temple.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: DivineTheme.creamDark),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black54, Colors.transparent, Colors.black54],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    labelColor: DivineTheme.maroon,
                    unselectedLabelColor: DivineTheme.textLight,
                    indicatorColor: DivineTheme.maroon,
                    indicatorWeight: 3.0,
                    tabs: const [
                      Tab(text: 'Virtual'),
                      Tab(text: 'Overview'),
                      Tab(text: 'Services'),
                      Tab(text: 'Feed'),
                      Tab(text: 'Priests'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Tab 1: Virtual Darshan Preview
              _buildVirtualDarshanTab(context),
              // Tab 2: Overview & Gallery Grid
              _buildOverviewTab(context),
              // Tab 3: Puja Services
              _buildServicesTab(context, app, templeServices),
              // Tab 4: Social Posts
              _buildFeedTab(context, templePosts),
              // Tab 5: Active Priests
              _buildPriestsTab(context, templePriests),
            ],
          ),
        ),
        // Sticky Cart Summary at bottom if not empty
        bottomSheet: app.cart.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${app.cart.length} Service${app.cart.length > 1 ? "s" : ""} Selected',
                            style: const TextStyle(fontSize: 11, color: DivineTheme.textLight, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${app.cartTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DivineTheme.maroon),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DivineTheme.saffron,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('VIEW CART', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildVirtualDarshanTab(BuildContext context) {
    final images = widget.temple.galleryImages.isNotEmpty
        ? widget.temple.galleryImages
        : [widget.temple.coverImage.isNotEmpty ? widget.temple.coverImage : widget.temple.profileImage];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DivineTheme.gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: DivineTheme.creamDark,
                      child: Icon(Icons.view_in_ar, color: DivineTheme.maroon, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Virtual Darshan',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: DivineTheme.textDark,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A lightweight 360-style preview for your demo flow.',
                            style: TextStyle(color: DivineTheme.textLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _tourController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _tourIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final image = images[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: DivineTheme.creamDark,
                                    child: const Icon(Icons.image_not_supported, color: DivineTheme.maroon),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.35),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.25),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.temple.name} • View ${index + 1}/${images.length}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Swipe or use the arrows to move around the shrine.',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(alpha: 0.35),
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: _tourIndex == 0
                                  ? null
                                  : () {
                                      _tourController.previousPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOut,
                                      );
                                    },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(alpha: 0.35),
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: _tourIndex == images.length - 1
                                  ? null
                                  : () {
                                      _tourController.nextPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOut,
                                      );
                                    },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _tourIndex == index ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _tourIndex == index ? DivineTheme.maroon : DivineTheme.gold.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _tourIndex = 0;
                          });
                          _tourController.jumpToPage(0);
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('RESET VIEW'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DivineTheme.maroon,
                          side: const BorderSide(color: DivineTheme.maroon),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                backgroundColor: Colors.black,
                                body: Center(
                                  child: Text(
                                    'LIVE DARSHAN STARTS AT BOOKED TIME',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.videocam),
                        label: const Text('LIVE ROOM'),
                        style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Address (Clickable)
          InkWell(
            onTap: () async {
              final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${widget.temple.name} ${widget.temple.address}")}';
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
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: DivineTheme.saffron),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.temple.address,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: DivineTheme.maroon,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'About Temple',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            widget.temple.description,
            style: const TextStyle(color: DivineTheme.textLight, height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text(
            'Temple Gallery',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.textDark),
          ),
          const SizedBox(height: 12),
          if (widget.temple.galleryImages.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No photos in gallery.', style: TextStyle(color: DivineTheme.textLight)),
              ),
            )
          else GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.temple.galleryImages.length,
              itemBuilder: (context, index) {
                final img = widget.temple.galleryImages[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: InteractiveViewer(
                            child: Image.network(img),
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: DivineTheme.creamDark),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildServicesTab(BuildContext context, AppProvider app, List<ServiceModel> services) {
    if (services.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No offerings listed currently.', style: TextStyle(color: DivineTheme.textLight)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final ServiceModel s = services[index];
        final cartItems = app.cart.where((item) => item.service.id == s.id).toList();
        final isInCart = cartItems.isNotEmpty;
        final totalQty = cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: DivineTheme.textDark,
                              ),
                            ),
                          ),
                          if (s.isVideoCall) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.videocam, color: DivineTheme.saffron, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${s.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showPujaDetailsSheet(context, s),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'View Details / Rules',
                              style: TextStyle(
                                fontSize: 11,
                                color: DivineTheme.saffron,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 14, color: DivineTheme.saffron),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.description,
                        style: const TextStyle(
                          color: DivineTheme.textLight,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isInCart) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: cartItems.map((item) {
                            return Chip(
                              label: Text('${item.selectedTimeSlot} (${item.quantity})', style: const TextStyle(fontSize: 9, color: DivineTheme.maroon)),
                              backgroundColor: DivineTheme.creamDark.withValues(alpha: 0.4),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          s.image.isNotEmpty ? s.image : widget.temple.profileImage,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: DivineTheme.creamDark,
                            child: const Icon(Icons.account_balance, color: DivineTheme.maroon, size: 28),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      child: Container(
                        height: 26,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: DivineTheme.saffron,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isInCart
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final lastItem = cartItems.last;
                                      app.decrementQuantity(lastItem);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.remove, size: 10, color: DivineTheme.saffron),
                                    ),
                                  ),
                                  Text(
                                    '$totalQty',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DivineTheme.saffron),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      _showSlotPickerSheet(context, app, s);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.add, size: 10, color: DivineTheme.saffron),
                                    ),
                                  ),
                                ],
                              )
                            : InkWell(
                                onTap: () {
                                  _showSlotPickerSheet(context, app, s);
                                },
                                borderRadius: BorderRadius.circular(13),
                                child: const Center(
                                  child: Text(
                                    'ADD',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: DivineTheme.saffron,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedTab(BuildContext context, List<PostModel> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No updates posted yet.', style: TextStyle(color: DivineTheme.textLight)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final p = posts[index];
        final timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(p.timestamp));

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(p.authorImage),
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                          Text(timeStr, style: const TextStyle(fontSize: 9, color: DivineTheme.textLight)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (p.caption.isNotEmpty)
                  Text(
                    p.caption,
                    style: const TextStyle(fontSize: 12, color: DivineTheme.textDark, height: 1.4),
                  ),
                if (p.imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      p.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriestsTab(BuildContext context, List<PriestModel> priests) {
    if (priests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No active priests registered.', style: TextStyle(color: DivineTheme.textLight)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: priests.length,
      itemBuilder: (context, index) {
        final pr = priests[index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    pr.photo,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: DivineTheme.creamDark,
                      child: const Icon(Icons.person, color: DivineTheme.maroon),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Experience: ${pr.experience}',
                        style: const TextStyle(fontSize: 11, color: DivineTheme.textLight),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pr.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: DivineTheme.textLight, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Delegate for persistent header (TabBar)
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
