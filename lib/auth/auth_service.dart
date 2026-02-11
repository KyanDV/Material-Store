import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_store/auth/otp_verification_screen.dart';
import 'package:material_store/services/otp_service.dart';
import 'package:material_store/user/user_home_screen.dart';

/// Data sementara untuk proses pendaftaran
class PendingSignUpData {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String role; // 'customer', 'worker', 'admin', etc.

  PendingSignUpData({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.role,
  });
}

class AuthService {
  static final supabase = Supabase.instance.client;

  // Pending data untuk OTP flow
  static String? _pendingEmail;
  static PendingSignUpData? pendingSignUp;

  /// Memulai proses pendaftaran - kirim OTP ke email
  static Future<void> startSignUp(
    BuildContext context, {
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    String role = 'customer',
  }) async {
    try {
      // Simpan data pending
      pendingSignUp = PendingSignUpData(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        role: role,
      );
      _pendingEmail = email;

      // Cek apakah email sudah terdaftar di Supabase (optional, backend also checks)
      // Check skipped here, backend logic in OTPService.register will handle uniqueness constraints
      
      // Kirim OTP via NodeJS backend
      final result = await OTPService.sendOTP(email);

      if (result['success'] == true) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => OTPVerificationScreen(email: email),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengirim OTP'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in startSignUp: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Verifikasi OTP dan selesaikan proses pendaftaran
  static Future<void> submitOTP(BuildContext context, String otp) async {
    try {
      final pending = pendingSignUp;
      final email = _pendingEmail;

      if (pending == null || email == null) {
        throw Exception('Data pendaftaran tidak ditemukan. Silakan ulang.');
      }

      // Final Register Call to Backend with OTP
      final result = await OTPService.register(
        fullName: pending.fullName,
        email: pending.email,
        phoneNumber: pending.phoneNumber,
        password: pending.password,
        otp: otp,
        role: pending.role,
      );

      if (result['success'] != true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Registrasi gagal'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Success!
      debugPrint('User registered: $email');

      // Sign in anonymously to Supabase for RLS (matching frontend repo logic)
      // Or sign in with credentials if the backend created a Supabase user
      // Note: The backend creates a Supabase Auth User OR just a record in 'users' table?
      // Looking at backend index.js:
      // It inserts into 'users' table (custom table), it does NOT seem to use Supabase Auth to create a user.
      // Wait, let's re-read backend index.js lines 198-207.
      // .from('users').insert({...data, password_hash...})
      // It creates a row in 'users' table. It does NOT use `supabase.auth.signUp`.
      // The login endpoint (lines 240-288) verifies against 'users' table.
      // So this is a CUSTOM AUTH system using Supabase DB but not Supabase Auth.
      
      // However, the frontend `auth.dart` line 158 calls `supabase.auth.signInAnonymously()`.
      // This allows the app to interact with Supabase RLS if policies allow anon.
      
      await supabase.auth.signInAnonymously();

      // Clear pending
      pendingSignUp = null;
      _pendingEmail = null;

      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registrasi berhasil!'),
              backgroundColor: Colors.green,
            ),
          );
         
         // Navigate to Home/Dashboard
         // For now, clear nav stack and go to UserHomeScreen
         Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
            (route) => false,
         );
      }

    } catch (e) {
      debugPrint('Error in submitOTP: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Kirim ulang OTP
  static Future<bool> resendOTP(BuildContext context) async {
    try {
      final email = _pendingEmail;
      if (email == null) {
        throw Exception('Email tidak ditemukan');
      }

      final result = await OTPService.sendOTP(email);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'OTP dikirim'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }

      return result['success'] == true;
    } catch (e) {
      debugPrint('Error resending OTP: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }
}
