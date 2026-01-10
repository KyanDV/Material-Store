// lib/owner/owner_home_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_store/owner/edit_store_screen.dart';
import 'package:material_store/owner/manage_products_screen.dart';
import 'package:material_store/owner/register_store_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final User? currentUser = Supabase.instance.client.auth.currentUser;

  // Fungsi untuk logout dari akun
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    // AuthGate akan menangani navigasi kembali ke LoginScreen secara otomatis.
  }

  // Fungsi untuk menghapus toko dari Supabase
  Future<void> _deleteStore(String storeId) async {
    try {
      await Supabase.instance.client.from('stores').delete().eq('id', storeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toko berhasil dihapus.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus toko: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Fungsi untuk menampilkan dialog konfirmasi sebelum menghapus
  void _showDeleteConfirmationDialog(String storeId, String storeName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Toko'),
          content: Text('Apakah Anda yakin ingin menghapus toko "$storeName"? Tindakan ini tidak dapat dibatalkan.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                _deleteStore(storeId);      // Lanjutkan proses hapus
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Pemilik Toko'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Pilih Peran Lain',
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout dari Akun',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Mengambil data toko yang 'id'-nya sama dengan ID pengguna yang login
        stream: Supabase.instance.client
            .from('stores')
            .stream(primaryKey: ['id'])
            .eq('id', currentUser!.id),
        builder: (context, snapshot) {
          // Tampilkan loading indicator saat data sedang diambil
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Tampilkan pesan error jika terjadi masalah
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan saat memuat data.'));
          }
          // Tampilkan pesan jika tidak ada toko yang terdaftar
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Anda belum memiliki toko.\nSilakan daftarkan toko baru.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // Jika data berhasil diambil, simpan dalam sebuah variabel
          var storeDocs = snapshot.data!;

          // Tampilkan daftar toko menggunakan ListView.builder
          return ListView.builder(
            itemCount: storeDocs.length,
            itemBuilder: (context, index) {
              var storeData = storeDocs[index];
              String storeId = storeData['id'];
              String storeName = storeData['storeName'] ?? 'Nama Toko Tidak Ada';
              String storeAddress = storeData['address'] ?? 'Alamat Tidak Ada';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront, color: Colors.blue, size: 40),
                      title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(storeAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        // Aksi default saat item di-tap adalah mengedit toko
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditStoreScreen(storeId: storeId),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    // Baris yang berisi tombol-tombol aksi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit Toko'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => EditStoreScreen(storeId: storeId),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.inventory_2, size: 18),
                          label: const Text('Kelola Produk'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ManageProductsScreen(
                                  storeId: storeId,
                                  storeName: storeName,
                                ),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            _showDeleteConfirmationDialog(storeId, storeName);
                          },
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      // Tombol untuk mendaftarkan toko baru
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const RegisterStoreScreen()),
          );
        },
        label: const Text('Daftarkan Toko Baru'),
        icon: const Icon(Icons.add_business),
      ),
    );
  }
}