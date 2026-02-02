// lib/user/user_home_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
       debugPrint('Location Error: $e');
       if (mounted) setState(() {
         _loadingMessage = 'Gagal mendapatkan lokasi: $e';
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari toko material...',
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          
          // Location Status (With Debug Info)
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
            )
          else if (_currentLocation == null)
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                     const Icon(Icons.location_off, size: 16, color: Colors.red),
                     const SizedBox(width: 8),
                     Expanded(child: Text('Lokasi tidak ditemukan: $_loadingMessage', style: const TextStyle(fontSize: 12, color: Colors.red))),
                     IconButton(icon: const Icon(Icons.refresh, size: 16), onPressed: _determinePosition)
                  ],
                ),
              ),
            ),

          // Store List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('stores')
                  .stream(primaryKey: ['id'])
                  .eq('status', 'Approved'),
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
                  String address = (data['address'] ?? '').toLowerCase();
                  return name.contains(_searchText) || address.contains(_searchText);
                }).toList();

                if (docs.isEmpty) {
                   return const Center(child: Text('Tidak ada toko yang cocok dengan pencarian.'));
                }

                final myLoc = _currentLocation;
                if (myLoc != null) {
                  docs.sort((a, b) {
                     var latA = (a['latitude'] as num?)?.toDouble();
                     var lngA = (a['longitude'] as num?)?.toDouble();
                     var latB = (b['latitude'] as num?)?.toDouble();
                     var lngB = (b['longitude'] as num?)?.toDouble();
                     
                     if (latA == null || lngA == null) return 1; // A to bottom
                     if (latB == null || lngB == null) return -1; // B to bottom
                     
                     double distA = _calculateDistance(myLoc.latitude, myLoc.longitude, latA, lngA);
                     double distB = _calculateDistance(myLoc.latitude, myLoc.longitude, latB, lngB);
                     
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
                    String? openingHours = data['opening_hours'];
                    bool isDelivery = data['is_delivery'] ?? false;

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

                    return StoreCard(
                      storeName: storeName,
                      address: address,
                      imageUrl: imageUrl,
                      openingHours: openingHours,
                      isDelivery: isDelivery,
                      distanceText: distanceText,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoreDetailScreen(storeId: data['id']),
                          ),
                        );
                      },
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

class StoreCard extends StatefulWidget {
  final String storeName;
  final String address;
  final String? imageUrl;
  final String? openingHours;
  final bool isDelivery;
  final String distanceText;
  final VoidCallback onTap;

  const StoreCard({
    super.key,
    required this.storeName,
    required this.address,
    this.imageUrl,
    this.openingHours,
    required this.isDelivery,
    required this.distanceText,
    required this.onTap,
  });

  @override
  State<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<StoreCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Colors from User Requirement
    final Color hoverColor = const Color(0xFFCFAB8D);
    final Color defaultColor = const Color(0xFFF0E4D3);
    final Color primaryColor = Theme.of(context).primaryColor;

    return Card(
      color: _isHovered ? hoverColor : defaultColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: _isHovered ? 6 : 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        onHover: (value) {
          setState(() {
            _isHovered = value;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Store Image (Full Width)
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.store, color: Colors.grey)),
                        )
                      : Container(color: primaryColor.withOpacity(0.1), child: Icon(Icons.store, size: 50, color: primaryColor.withOpacity(0.5))),
                  
                  // Distance Badge
                  if (widget.distanceText.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me, size: 14, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              widget.distanceText,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Store Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.storeName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: TextStyle(color: Colors.black87, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (widget.openingHours != null && widget.openingHours!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(widget.openingHours!, style: const TextStyle(fontSize: 11, color: Colors.black)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (widget.distanceText.isNotEmpty)
                         Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Row(
                            children: [
                              Icon(Icons.near_me, size: 14, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                widget.distanceText,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).primaryColor),
                              ),
                            ],
                          ),
                        ),
                      if (widget.isDelivery)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFA8112), 
                            borderRadius: BorderRadius.circular(12),
                            // border: Border.all(color: primaryColor.withOpacity(0.2)), // Removing border for clean look
                          ),
                          child: const Text('Siap Antar', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

