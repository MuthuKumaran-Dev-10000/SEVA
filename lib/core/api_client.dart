import 'package:flutter/foundation.dart';
import '../features/auth/auth_service.dart';
import '../features/family/family_service.dart';
import '../features/temple/temple_service.dart';
import '../features/service/service_service.dart';
import '../features/booking/booking_service.dart';
import '../features/auspicious/auspicious_service.dart';

class ApiClient extends ChangeNotifier {
  // Services (Microservices)
  final AuthService authService = AuthService();
  final FamilyService familyService = FamilyService();
  final TempleService templeService = TempleService();
  final ServiceService serviceService = ServiceService();
  late final BookingService bookingService;
  final AuspiciousService auspiciousService = AuspiciousService();

  bool _isConnected = true;
  String _baseUrl = 'https://lubrication-indicator-default-rtdb.firebaseio.com';

  String get baseUrl => _baseUrl;
  bool get isConnected => _isConnected;

  ApiClient() {
    bookingService = BookingService(templeService, serviceService);
    checkConnection();
  }

  Future<void> setBaseUrl(String url) async {
    // Keep this as a dummy/no-op to not break settings UI
    _baseUrl = url;
    notifyListeners();
  }

  Future<bool> checkConnection() async {
    // Direct connection to Firebase cloud database, so always true if device has internet
    _isConnected = true;
    notifyListeners();
    return true;
  }

  // GET Request Router
  Future<dynamic> get(String path) async {
    try {
      final uri = Uri.parse(path);
      final cleanPath = uri.path;
      final queryParams = uri.queryParameters;
      final segments = uri.pathSegments;

      if (cleanPath == '/temples') {
        return await templeService.getTemples();
      }
      
      if (cleanPath.startsWith('/temples/')) {
        if (cleanPath == '/temples/stats') {
          final userId = int.parse(queryParams['user_id']!);
          return await templeService.getTempleStats(userId);
        }
        if (cleanPath == '/temples/invites') {
          final userId = int.parse(queryParams['user_id']!);
          return await templeService.getTempleSentInvites(userId);
        }
        if (cleanPath == '/temples/priests') {
          final userId = int.parse(queryParams['user_id']!);
          return await templeService.getTempleAssociatedPriests(userId);
        }
        
        final templeIdStr = segments.last;
        final templeId = int.parse(templeIdStr);
        return await templeService.getTempleDetails(templeId);
      }
      
      if (cleanPath == '/services') {
        final query = queryParams['query'];
        return await serviceService.getAllServices(query);
      }
      
      if (cleanPath == '/auspicious-days') {
        return await auspiciousService.getAuspiciousDays();
      }
      
      if (cleanPath == '/timings/slots') {
        final serviceId = int.parse(queryParams['service_id']!);
        final date = queryParams['date']!;
        return await bookingService.getSlotsStatus(serviceId, date);
      }
      
      if (cleanPath == '/bookings/history') {
        final userId = int.parse(queryParams['user_id']!);
        return await bookingService.getBookingHistory(userId);
      }
      
      if (cleanPath == '/family') {
        final userId = int.parse(queryParams['user_id']!);
        return await familyService.getFamily(userId);
      }
      
      if (cleanPath == '/priests/search') {
        final email = queryParams['email']!;
        return await templeService.searchPriest(email);
      }
      
      if (cleanPath == '/priests/invitations') {
        final priestId = int.parse(queryParams['priest_id']!);
        return await templeService.getPriestReceivedInvites(priestId);
      }

      throw Exception('GET route not matched: $path');
    } catch (e) {
      debugPrint('ApiClient GET Error: $e');
      rethrow;
    }
  }

  // POST Request Router
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(path);
      final cleanPath = uri.path;
      final queryParams = uri.queryParameters;

      if (cleanPath == '/auth/login') {
        final email = body['email']!;
        final password = body['password']!;
        return await authService.login(email, password);
      }
      
      if (cleanPath == '/auth/signup') {
        return await authService.signup(body);
      }
      
      if (cleanPath == '/family/add') {
        final userId = int.parse(queryParams['user_id']!);
        return await familyService.addFamilyMember(userId, body);
      }
      
      if (cleanPath == '/bookings/book') {
        final userId = int.parse(queryParams['user_id']!);
        return await bookingService.bookSeva(body, userId);
      }
      
      if (cleanPath == '/payments/checkout') {
        final bookingId = int.parse(queryParams['booking_id']!);
        await bookingService.checkoutAndPay(bookingId);
        return {'status': 'success', 'message': 'Seva booked successfully!'};
      }
      
      if (cleanPath == '/bookings/respond') {
        final bookingId = int.parse(queryParams['booking_id']!);
        final priestId = int.parse(queryParams['priest_id']!);
        final status = queryParams['status']!;
        await bookingService.respondToBooking(bookingId, priestId, status);
        return {'status': 'success', 'message': 'Service booking $status.'};
      }
      
      if (cleanPath == '/temples/invite') {
        final userId = int.parse(queryParams['user_id']!);
        final priestEmail = body['priest_email']!;
        await templeService.sendPriestInvitation(userId, priestEmail);
        return {'status': 'success', 'message': 'Recruitment invitation sent to priest!'};
      }
      
      if (cleanPath == '/priests/invitations/respond') {
        final inviteId = int.parse(queryParams['invite_id']!);
        final status = queryParams['status']!;
        await templeService.respondToInvitation(inviteId, status);
        return {'status': 'success', 'message': 'Invitation $status.'};
      }

      throw Exception('POST route not matched: $path');
    } catch (e) {
      debugPrint('ApiClient POST Error: $e');
      rethrow;
    }
  }

  // PUT Request Router
  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(path);
      final cleanPath = uri.path;

      if (cleanPath == '/auth/profile') {
        return await authService.updateProfile(body);
      }

      throw Exception('PUT route not matched: $path');
    } catch (e) {
      debugPrint('ApiClient PUT Error: $e');
      rethrow;
    }
  }

  // Multipart File Upload Router
  Future<dynamic> uploadFile(String path, String filePath, Map<String, String> fields) async {
    try {
      final uri = Uri.parse(path);
      final cleanPath = uri.path;

      if (cleanPath == '/auth/profile/avatar') {
        final userId = int.parse(fields['user_id']!);
        return await authService.uploadAvatar(userId, filePath);
      }

      throw Exception('Multipart route not matched: $path');
    } catch (e) {
      debugPrint('ApiClient uploadFile Error: $e');
      rethrow;
    }
  }
}
