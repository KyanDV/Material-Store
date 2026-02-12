import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service untuk mengirim dan verifikasi OTP via NodeJS backend
class OTPService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    String url = dotenv.env['OTP_SERVER_URL'] ?? 'http://10.0.2.2:3000';
    
    // Khusus Android Emulator, localhost harus diganti 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android && url.contains('localhost')) {
      url = url.replaceFirst('localhost', '10.0.2.2');
    }
    
    // Remove trailing slash if present
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Kirim OTP ke email
  /// Returns: Map dengan 'success' (bool) dan 'message' (String)
  static Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 60)); // Timeout 60 detik untuk antisipasi cold start

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'message': 'Koneksi Timeout. Server mungkin sedang "tidur" (Cold Start). Silakan coba lagi sebentar lagi.',
      };
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungi server: $e',
      };
    }
  }

  /// Register user with OTP verification
  /// Returns: Map key 'success' (bool) dan 'message' (String)
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String otp,
    required String role, // Changed enum to String for simplicity in service
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'password': password,
          'otp': otp,
          'role': role,
        }),
        'role': role,
        }),
      ).timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
      };
    } on TimeoutException catch (_) {
      return {
        'success': false,
        'message': 'Koneksi Timeout saat registrasi. Silakan coba lagi.',
      };
    } catch (e) {
      debugPrint('Error registering: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungi server: $e',
      };
    }
  }

  /// Login with identifier (email/phone) and password
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      // Jika login sukses, return data user juga
      if (data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungi server: $e',
      };
    }
  }
}
