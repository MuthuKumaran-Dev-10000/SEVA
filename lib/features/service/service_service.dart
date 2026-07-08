import 'package:firebase_database/firebase_database.dart';

class ServiceService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<List<Map<String, dynamic>>> getAllServices(String? query) async {
    try {
      // 1. Fetch services
      final servicesSnapshot = await _dbRef.child('Seva-v1/services').get();
      if (!servicesSnapshot.exists || servicesSnapshot.value == null) {
        return [];
      }

      final List<Map<String, dynamic>> rawServices = [];
      final servicesData = servicesSnapshot.value;

      if (servicesData is Map) {
        servicesData.forEach((key, val) {
          if (val is Map) {
            rawServices.add(Map<String, dynamic>.from(val));
          }
        });
      } else if (servicesData is List) {
        for (final val in servicesData) {
          if (val is Map) {
            rawServices.add(Map<String, dynamic>.from(val));
          }
        }
      }

      // 2. Fetch temples to associate with services
      final templesSnapshot = await _dbRef.child('Seva-v1/temples').get();
      final Map<int, Map<String, dynamic>> templesMap = {};
      if (templesSnapshot.exists && templesSnapshot.value != null) {
        final templesData = templesSnapshot.value;
        void addTemple(dynamic val) {
          if (val is Map) {
            final t = Map<String, dynamic>.from(val);
            final id = t['id'];
            if (id is int) {
              templesMap[id] = t;
            } else if (id is String) {
              final parsed = int.tryParse(id);
              if (parsed != null) templesMap[parsed] = t;
            }
          }
        }
        if (templesData is Map) {
          templesData.values.forEach(addTemple);
        } else if (templesData is List) {
          templesData.forEach(addTemple);
        }
      }

      // 3. Compile and filter results
      final List<Map<String, dynamic>> results = [];
      final q = query?.trim().toLowerCase();

      for (final s in rawServices) {
        final templeId = s['temple_id'];
        final temple = templesMap[templeId];
        if (temple == null) continue;

        if (q != null && q.isNotEmpty) {
          final sName = (s['name'] ?? '').toString().toLowerCase();
          final sDesc = (s['description'] ?? '').toString().toLowerCase();
          final tName = (temple['name'] ?? '').toString().toLowerCase();
          if (!sName.contains(q) && !sDesc.contains(q) && !tName.contains(q)) {
            continue;
          }
        }

        results.add({
          'id': s['id'],
          'name': s['name'],
          'price': s['price'] is num ? (s['price'] as num).toDouble() : 0.0,
          'description': s['description'],
          'duration': s['duration'],
          'temple_id': templeId,
          'temple': temple
        });
      }

      return results;
    } catch (e) {
      throw Exception('Failed to get services: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getServicesByTemple(int templeId) async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/services').get();
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final List<Map<String, dynamic>> services = [];
      final data = snapshot.value;

      void addService(dynamic val) {
        if (val is Map) {
          final s = Map<String, dynamic>.from(val);
          if (s['temple_id'] == templeId) {
            services.add({
              'id': s['id'],
              'temple_id': s['temple_id'],
              'name': s['name'],
              'price': s['price'] is num ? (s['price'] as num).toDouble() : 0.0,
              'description': s['description'],
              'duration': s['duration'],
            });
          }
        }
      }

      if (data is Map) {
        data.values.forEach(addService);
      } else if (data is List) {
        data.forEach(addService);
      }

      return services;
    } catch (e) {
      throw Exception('Failed to get temple services: $e');
    }
  }
}
