import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api_client.dart';
import '../../core/providers/booking_flow_provider.dart';
import '../../core/theme.dart';

class TemplesTab extends StatefulWidget {
  final TabController tabController;
  const TemplesTab({super.key, required this.tabController});

  @override
  State<TemplesTab> createState() => _TemplesTabState();
}

class _TemplesTabState extends State<TemplesTab> {
  List<dynamic> _temples = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTemples();
  }

  Future<void> _fetchTemples() async {
    final client = Provider.of<ApiClient>(context, listen: false);
    await client.checkConnection();
    if (!client.isConnected) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Server offline. Click the wifi icon in the top right to configure.";
        });
      }
      return;
    }

    try {
      final data = await client.get('/temples');
      if (mounted) {
        setState(() {
          _temples = data;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = Provider.of<BookingFlowProvider>(context);

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
              const Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.outfit(color: SevaTheme.textCharcoal, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchTemples();
                },
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _temples.length,
      itemBuilder: (context, index) {
        final temple = _temples[index];
        final isSelected = flow.selectedTempleId == temple['id'];

        return GestureDetector(
          onTap: () {
            flow.selectTemple(temple['id'], temple['name'], widget.tabController);
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected ? SevaTheme.secondaryGold : SevaTheme.primaryMaroon.withOpacity(0.06),
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.network(
                  temple['image_url'],
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: SevaTheme.primaryMaroon.withOpacity(0.1),
                    child: const Icon(Icons.temple_hindu, size: 48, color: SevaTheme.secondaryGold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              temple['name'],
                              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? SevaTheme.secondaryGold.withOpacity(0.15) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isSelected ? 'Selected' : 'Select Temple',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? SevaTheme.secondaryGold : SevaTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: SevaTheme.secondaryGold),
                          const SizedBox(width: 4),
                          Text(
                            temple['location'],
                            style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        temple['description'],
                        style: GoogleFonts.outfit(fontSize: 13, color: SevaTheme.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
