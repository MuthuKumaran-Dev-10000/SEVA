import 'package:flutter/material.dart';
import '../core/services/firebase_service.dart';
import '../core/theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    if (service.isFirebaseAvailable) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: DivineTheme.saffron.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo Mode (Local DB). Connect Firebase anytime using flutterfire configure.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
