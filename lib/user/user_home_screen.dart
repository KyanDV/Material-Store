// lib/user/user_home_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_store/user/store_detail_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  LatLng? _currentLocation;
  String _loadingMessage = 'Mencari lokasi Anda...';
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
       if (mounted) setState(() {
         _loadingMessage = 'Layanan lokasi tidak aktif.';
         _isLoadingLocation = false;
       });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() {
          _loadingMessage = 'Izin lokasi ditolak.';
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
       if (mounted) setState(() {
         _loadingMessage = 'Izin lokasi ditolak permanen.';
         _isLoadingLocation = false;
       });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
       if (mounted) setState(() {
         _loadingMessage = 'Gagal mendapatkan lokasi.';
         _isLoadingLocation = false;
       });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Toko Material'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _determinePosition,
            tooltip: 'Perbarui Lokasi',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama toko...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          
          // Location Status (Optional)
          if (_isLoadingLocation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(_loadingMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          // Store List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('stores').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.domain_disabled, size: 64, color: Colors.grey),
                         SizedBox(height: 16),
                         Text('Belum ada toko yang terdaftar.'),
                      ],
                    ),
                  );
                }

                // Filter and Sort Data
                var docs = snapshot.data!.where((data) {
                  String name = (data['storeName'] ?? '').toLowerCase();
                  return name.contains(_searchText);
                }).toList();

                if (docs.isEmpty) {
                   return const Center(child: Text('Tidak ada toko yang cocok dengan pencarian.'));
                }

                if (_currentLocation != null) {
                  docs.sort((a, b) {
                     var latA = (a['latitude'] as num?)?.toDouble();
                     var lngA = (a['longitude'] as num?)?.toDouble();
                     var latB = (b['latitude'] as num?)?.toDouble();
                     var lngB = (b['longitude'] as num?)?.toDouble();
                     
                     if (latA == null || lngA == null || latB == null || lngB == null) return 0;
                     
                     double distA = _calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, latA, lngA);
                     double distB = _calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, latB, lngB);
                     
                     return distA.compareTo(distB);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index];
                    String storeName = data['storeName'] ?? 'Toko Tanpa Nama';
                    String address = data['address'] ?? 'Alamat tidak tersedia';
                    String? imageUrl = data['imageUrl'];
                    double? lat = (data['latitude'] as num?)?.toDouble();
                    double? lng = (data['longitude'] as num?)?.toDouble();

                    String distanceText = '';
                    if (_currentLocation != null && lat != null && lng != null) {
                      double distInMeters = _calculateDistance(
                        _currentLocation!.latitude, 
                        _currentLocation!.longitude, 
                        lat, 
                        lng
                      );
                      if (distInMeters > 1000) {
                        distanceText = '${(distInMeters / 1000).toStringAsFixed(1)} km';
                      } else {
                        distanceText = '${distInMeters.toStringAsFixed(0)} m';
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreDetailScreen(storeId: data['id']),
                            ),
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store Image
                            Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, _) => const Icon(Icons.store, size: 40, color: Colors.grey),
                                    )
                                  : Icon(Icons.store, size: 40, color: Theme.of(context).primaryColor),
                            ),
                            
                            // Store Details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            storeName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (distanceText.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                            ),
                                            child: Text(
                                              distanceText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      address,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    // Optional: Rating or Open/Close status could be added here
                                    Row(
                                      children: [
                                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                        const SizedBox(width: 4),
                                        Text('4.8', style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                                        const SizedBox(width: 12),
                                        // Just a placeholder for style
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50], 
                                            borderRadius: BorderRadius.circular(4)
                                          ),
                                          child: Text(
                                            'Material',
                                            style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}

