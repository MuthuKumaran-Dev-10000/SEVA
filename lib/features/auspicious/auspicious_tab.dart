import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

class AuspiciousTab extends StatefulWidget {
  const AuspiciousTab({super.key});

  @override
  State<AuspiciousTab> createState() => _AuspiciousTabState();
}

class _AuspiciousTabState extends State<AuspiciousTab> {
  List<dynamic> _dates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAuspiciousDays();
  }

  Future<void> _fetchAuspiciousDays() async {
    final client = Provider.of<ApiClient>(context, listen: false);
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
      final data = await client.get('/auspicious-days');
      if (mounted) {
        setState(() {
          _dates = data;
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
              Text(_error!, style: GoogleFonts.outfit(fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchAuspiciousDays();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: SevaTheme.secondaryGold.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: SevaTheme.secondaryGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming auspicious calendar days for special prayers.',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _dates.length,
            itemBuilder: (context, index) {
              final day = _dates[index];
              final DateTime parsedDate = DateTime.parse(day['date']);
              final dayStr = DateFormat('dd').format(parsedDate);
              final monthStr = DateFormat('MMM').format(parsedDate);
              final weekdayStr = DateFormat('EEEE').format(parsedDate);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: SevaTheme.primaryMaroon.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: SevaTheme.primaryMaroon,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(dayStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(monthStr.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SevaTheme.secondaryGold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day['title'], 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: SevaTheme.primaryMaroon)
                            ),
                            Text(
                              weekdayStr, 
                              style: const TextStyle(fontSize: 11, color: SevaTheme.secondaryGold, fontWeight: FontWeight.w500)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              day['description'], 
                              style: const TextStyle(fontSize: 11, color: SevaTheme.textMuted)
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 12, color: SevaTheme.secondaryGold),
                                const SizedBox(width: 4),
                                Text(
                                  'Auspicious Hours: ${day['auspicious_time']}', 
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal)
                                ),
                              ],
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
        ),
      ],
    );
  }
}
