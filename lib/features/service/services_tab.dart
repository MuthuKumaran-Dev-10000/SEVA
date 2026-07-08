import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api_client.dart';
import '../../core/providers/booking_flow_provider.dart';
import '../../core/theme.dart';

class ServicesTab extends StatefulWidget {
  final TabController tabController;
  const ServicesTab({super.key, required this.tabController});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  List<dynamic> _services = [];
  List<dynamic> _filteredServices = [];
  bool _isLoading = false;
  String? _error;
  int? _lastFetchedTempleId;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices(int templeId) async {
    final client = Provider.of<ApiClient>(context, listen: false);
    if (!client.isConnected) {
      setState(() {
        _isLoading = false;
        _error = "Server offline.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await client.get('/temples/$templeId');
      final list = data['services'] ?? [];
      setState(() {
        _services = list;
        _filteredServices = list;
        _isLoading = false;
        _lastFetchedTempleId = templeId;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredServices = _services;
      } else {
        _filteredServices = _services
            .where((s) => s['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
                          s['description'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flow = Provider.of<BookingFlowProvider>(context);

    // 1. If no temple is selected, show prompt to select temple
    if (flow.selectedTempleId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.church, size: 64, color: SevaTheme.primaryMaroon.withOpacity(0.15)),
              const SizedBox(height: 16),
              Text(
                'No Temple Selected',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a temple from the first tab to view its services.',
                style: GoogleFonts.outfit(fontSize: 13, color: SevaTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => widget.tabController.animateTo(0),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Go to Temples'),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Fetch services if temple has changed
    if (_lastFetchedTempleId != flow.selectedTempleId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchServices(flow.selectedTempleId!);
      });
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.outfit(fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchServices(flow.selectedTempleId!),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Selection Banner
        Container(
          width: double.infinity,
          color: SevaTheme.secondaryGold.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.church_outlined, size: 16, color: SevaTheme.secondaryGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Temple: ${flow.selectedTempleName}',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                ),
              ),
              TextButton(
                onPressed: () => widget.tabController.animateTo(0),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: Text('Change', style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search services...',
              prefixIcon: Icon(Icons.search, color: SevaTheme.primaryMaroon),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        Expanded(
          child: _filteredServices.isEmpty
              ? Center(child: Text('No services found.', style: GoogleFonts.outfit(color: SevaTheme.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredServices.length,
                  itemBuilder: (context, index) {
                    final service = _filteredServices[index];
                    final isSelected = flow.selectedServiceId == service['id'];

                    return GestureDetector(
                      onTap: () {
                        flow.selectService(service['id'], service['name'], service['price'], widget.tabController);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? SevaTheme.secondaryGold : Colors.transparent,
                            width: isSelected ? 2 : 0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service['name'],
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: SevaTheme.primaryMaroon),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      service['description'],
                                      style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 14, color: SevaTheme.secondaryGold),
                                        const SizedBox(width: 4),
                                        Text(service['duration'], style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 20),
                                        const Icon(Icons.currency_rupee, size: 14, color: SevaTheme.secondaryGold),
                                        Text(
                                          '${service['price']}',
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: isSelected ? SevaTheme.secondaryGold : Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
