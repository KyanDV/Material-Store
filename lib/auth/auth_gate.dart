// lib/auth/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_store/auth/login_screen.dart';
import 'package:material_store/auth/role_selection_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Jika masih menunggu koneksi, tampilkan loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Jika pengguna sudah login, tampilkan layar pemilihan peran.
        if (snapshot.hasData) {
          return const RoleSelectionScreen();
        }

        // Jika pengguna belum login, tampilkan layar login.
        return const LoginScreen();
      },
    );
  }
}