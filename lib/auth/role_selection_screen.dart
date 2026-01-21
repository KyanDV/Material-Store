// lib/auth/role_selection_screen.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:material_store/owner/owner_home_screen.dart';
import 'package:material_store/user/user_home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  // --- FUNGSI BARU UNTUK LOGOUT ---
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    // Setelah logout, AuthGate akan secara otomatis mendeteksi perubahan
    // dan mengarahkan pengguna kembali ke LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- APPBAR BARU DITAMBAHKAN DI SINI ---
      appBar: AppBar(
        automaticallyImplyLeading: false, // Menyembunyikan tombol kembali otomatis
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout, // Panggil fungsi logout saat ditekan
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Masuk Sebagai',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text('Mencari Toko', style: TextStyle(color: Colors.black87)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UserHomeScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.store),
                label: const Text('Pemilik Toko'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: const Color(0xFFFBF3D5),
                  foregroundColor: Colors.black87,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const OwnerHomeScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
