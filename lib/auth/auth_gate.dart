// lib/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_store/auth/login_screen.dart';
import 'package:material_store/auth/role_selection_screen.dart';
import 'package:material_store/admin/admin_dashboard_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Cek session awal atau perubahan state
        final session = Supabase.instance.client.auth.currentSession;
        
        // Menggunakan session sebagai kebenaran
        if (session != null) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user?.email == 'admin1@gmail.com') {
            return const AdminDashboardScreen();
          }
          return const RoleSelectionScreen();
        }

        // Jika tidak ada session, login
        return const LoginScreen();
      },
    );
  }
}