import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_store/admin/store_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingStores = [];
  List<Map<String, dynamic>> _approvedStores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    setState(() => _isLoading = true);
    try {
      final pendingResponse = await _supabase
          .from('stores')
          .select()
          .eq('status', 'Pending')
          .order('created_at', ascending: false);
      
      final approvedResponse = await _supabase
          .from('stores')
          .select()
          .eq('status', 'Approved')
          .order('created_at', ascending: false);

      setState(() {
        _pendingStores = List<Map<String, dynamic>>.from(pendingResponse);
        _approvedStores = List<Map<String, dynamic>>.from(approvedResponse);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Verifikasi'),
              Tab(text: 'Terdaftar'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchStores,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
               onPressed: () async {
                await _supabase.auth.signOut();
               },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildStoreList(_pendingStores, isPending: true),
                  _buildStoreList(_approvedStores, isPending: false),
                ],
              ),
      ),
    );
  }

  Widget _buildStoreList(List<Map<String, dynamic>> stores, {required bool isPending}) {
    if (stores.isEmpty) {
      return Center(
        child: Text(isPending 
          ? 'Tidak ada permohonan baru.' 
          : 'Belum ada toko terdaftar.'
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.store, 
              color: isPending ? Colors.orange : Colors.green
            ),
            title: Text(store['storeName'] ?? 'Tanpa Nama'),
            subtitle: Text(store['address'] ?? '-'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
               await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoreVerificationScreen(storeData: store),
                ),
              );
              _fetchStores(); // Refresh on return
            },
          ),
        );
      },
    );
  }
}
