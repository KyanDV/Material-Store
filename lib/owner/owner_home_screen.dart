// lib/owner/owner_home_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_store/owner/edit_store_screen.dart';
import 'package:material_store/owner/manage_products_screen.dart';
import 'package:material_store/owner/register_store_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final User? currentUser = Supabase.instance.client.auth.currentUser;
  bool _isLoading = true;
  Map<String, dynamic>? _storeData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _storeData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data toko: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _deleteStore(String storeId) async {
    try {
      await Supabase.instance.client.from('stores').delete().eq('id', storeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toko berhasil dihapus.'), backgroundColor: Colors.green),
        );
        _fetchStoreData(); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus toko: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
                Navigator.of(context).pop();
                _deleteStore(storeId);
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
        title: const Text('Dashboard Toko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchStoreData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchStoreData, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    // If no store found
    if (_storeData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.store_outlined, size: 80, color: Colors.grey),
             const SizedBox(height: 16),
             const Text(
              'Anda belum memiliki toko.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const RegisterStoreScreen()),
                );
                _fetchStoreData(); // Refresh after return
              },
              icon: const Icon(Icons.add_business),
              label: const Text('Buat Toko Sekarang'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Store exists
    final storeId = _storeData!['id'];
    final storeName = _storeData!['storeName'] ?? 'Nama Toko';
    final storeAddress = _storeData!['address'] ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Header Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.store_mall_directory, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  Text(
                    storeName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    storeAddress,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Link to Maps (New Feature)
          Center(
            child: TextButton.icon(
              onPressed: () async {
                if (_storeData != null) {
                  final storeName = _storeData!['storeName'] ?? '';
                  final address = _storeData!['address'] ?? '';
                  
                  if (storeName.isNotEmpty) {
                     final String query = Uri.encodeComponent('$storeName $address');
                     final Uri uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                     if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka Maps')));
                        }
                     }
                  }
                }
              }, 
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Lihat Tampilan di Google Maps', style: TextStyle(color: Colors.black87)),
            ),
          ),
          const SizedBox(height: 16),
          
          // Menu Options
          const Text(
            'Menu Utama',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildMenuCard(
                  context,
                  icon: Icons.edit_note,
                  title: 'Info Toko',
                  subtitle: 'Ubah nama & alamat',
                  color: const Color(0xFFFBF3D5),
                  iconColor: Colors.black87,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditStoreScreen(storeId: storeId),
                      ),
                    );
                    _fetchStoreData(); // Refresh after return
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMenuCard(
                  context,
                  icon: Icons.inventory,
                  title: 'Produk',
                  subtitle: 'Kelola dagangan',
                  color: Colors.green.shade100,
                  iconColor: Colors.green,
                  onTap: () {
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
              ),
            ],
          ),

          const SizedBox(height: 32),
          
          // Danger Zone
          OutlinedButton.icon(
            onPressed: () => _showDeleteConfirmationDialog(storeId, storeName),
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Hapus Toko Permanen', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
