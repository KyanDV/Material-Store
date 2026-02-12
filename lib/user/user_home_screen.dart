// lib/user/user_home_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_store/user/store_detail_screen.dart';
import 'package:material_store/auth/login_screen.dart';
import 'package:material_store/auth/register_screen.dart';
import 'package:material_store/owner/owner_home_screen.dart';

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



  LatLng? _manualLocation;
  String _addressName = 'Pilih Alamat Destinasi';
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // Fungsi Cari Lokasi via OSM
  Future<void> _searchLocationOSM(String query) async {
    if (query.isEmpty) return;
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'MaterialStore/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newLoc = LatLng(lat, lon);
          
          setState(() {
            _manualLocation = newLoc;
            _markers = {
              Marker(
                markerId: const MarkerId('manual_loc'),
                position: newLoc,
                infoWindow: InfoWindow(title: data[0]['display_name']),
              )
            };
          });

          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLoc, 15));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi tidak ditemukan')));
        }
      }
    } catch (e) {
      debugPrint('Error OSM: $e');
    }
  }

  void _showManualLocationDialog() {
    final TextEditingController addressController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Pilih Alamat Destinasi'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Cari Alamat (Jalan, , )',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                             _searchLocationOSM(addressController.text).then((_) {
                               setStateDialog(() {});
                             });
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                         _searchLocationOSM(val).then((_) {
                           setStateDialog(() {});
                         });
                      },
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _manualLocation ?? _currentLocation ?? const LatLng(-6.2088, 106.8456),
                          zoom: 12,
                        ),
                        markers: _markers,
                        onMapCreated: (controller) => _mapController = controller,
                        onTap: (latLng) {
                           setStateDialog(() {
                             _manualLocation = latLng;
                             _markers = {
                               Marker(markerId: const MarkerId('manual_picked'), position: latLng)
                             };
                           });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Color(0xFF0A4A65))),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_manualLocation != null) {
                      setState(() {
                         _currentLocation = _manualLocation;
                         _addressName = addressController.text.isEmpty ? 'Lokasi Terpilih' : addressController.text; 
                         // Trigger update jarak toko (implementasi nanti di _searchStores / _calculateDistances)
                         // Asumsi: searchStores menggunakan _currentLocation
                      });
                         // _searchStores(); // Tidak perlu, setState sudah memicu rebuild

                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD3C389), // Gold background
                    foregroundColor: const Color(0xFF0A4A65), // Dark Blue text
                  ),
                  child: const Text('Gunakan Lokasi Ini'),
                ),
              ],
            );
          },
        );
      },
    );
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
        
        // Reverse Geocoding untuk mendapatkan nama jalan/kota dari GPS
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            setState(() {
              String street = place.street ?? '';
              String subLoc = place.subLocality ?? '';
              if (street.isEmpty && subLoc.isEmpty) {
                 _addressName = place.locality ?? 'Lokasi Anda';
              } else {
                 _addressName = '$street, $subLoc'.replaceAll(RegExp(r'^, |,$'), '');
              }
            });
          }
        } catch (e) {
          debugPrint('Reverse Geocoding Error: $e');
        }
      }
    } catch (e) {
       debugPrint('Location Error: $e');
       if (mounted) setState(() {
         _loadingMessage = 'Gagal mendapatkan lokasi: $e';
         _isLoadingLocation = false;
       });
    }
  }



  double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent to show body background
        elevation: 0,
        actions: [
          StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session != null) {
                return IconButton(
                   icon: const Icon(Icons.store, color: Color(0xFFD3C389)), // Gold Icon
                   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen())),
                   tooltip: 'Halaman Toko',
                );
              }
              return TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text(
                  'Masuk',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header Section (Search & Location)
          Container(
            padding: EdgeInsets.only(
              bottom: 24, 
              left: 16, 
              right: 16, 
              top: MediaQuery.of(context).padding.top + 10 // Adjust for status bar
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0A4A65), // Deep Blue
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Logo
                Image.asset(
                  'assets/images/Logo_KANG_JATI_Transparan.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),

                // Location Picker
                InkWell(
                  onTap: _showManualLocationDialog,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD3C389), size: 16), // Gold Location Icon
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _addressName,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari toko... (nama, alamat, kabupaten/kota)',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0A4A65)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFFD3C389), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Location Status & Error
          if (_isLoadingLocation)
             Padding(padding: const EdgeInsets.all(8.0), child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: Theme.of(context).primaryColor)),

          if (_currentLocation == null && !_isLoadingLocation)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                   const Icon(Icons.location_off, size: 20, color: Colors.red),
                   const SizedBox(width: 12),
                   Expanded(child: Text('Gagal mendapatkan lokasi: $_loadingMessage', style: const TextStyle(color: Colors.red, fontSize: 12))),
                   IconButton(icon: const Icon(Icons.refresh, color: Colors.red), onPressed: _determinePosition),
                ],
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
                         Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.grey),
                         SizedBox(height: 16),
                         Text('Belum ada toko di sekitar area ini.', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                   return const Center(child: Text('Tidak ada hasil pencarian.'));
                }

                final myLoc = _currentLocation;
                if (myLoc != null) {
                  docs.sort((a, b) {
                     var latA = (a['latitude'] as num?)?.toDouble();
                     var lngA = (a['longitude'] as num?)?.toDouble();
                     var latB = (b['latitude'] as num?)?.toDouble();
                     var lngB = (b['longitude'] as num?)?.toDouble();
                     
                     if (latA == null || lngA == null) return 1; 
                     if (latB == null || lngB == null) return -1;
                     
                     double distA = _calculateDistance(myLoc.latitude, myLoc.longitude, latA, lngA);
                     double distB = _calculateDistance(myLoc.latitude, myLoc.longitude, latB, lngB);
                     
                     return distA.compareTo(distB);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        distanceText = '${(distInMeters / 1000).toStringAsFixed(1)} KM';
                      } else {
                        distanceText = '${distInMeters.toStringAsFixed(0)} M';
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
    return Card(
      color: _isHovered ? const Color(0xFFD3C389) : Colors.white, // Gold logic
      elevation: _isHovered ? 6 : 4,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) {
           setState(() {
             _isHovered = value;
           });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Area
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(color: Colors.grey[100], child: const Icon(Icons.store, color: Colors.grey, size: 40)),
                        )
                      : Container(
                          color: const Color(0xFF0A4A65).withOpacity(0.1),
                          child: const Icon(Icons.store, size: 40, color: Color(0xFF0A4A65)),
                        ),
                  
                  // Distance Badge
                  if (widget.distanceText.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place, size: 14, color: Color(0xFFFA8112)), // Orange Icon
                            const SizedBox(width: 4),
                            Text(
                              widget.distanceText,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0A4A65)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Info Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Expanded(
                         child: Text(
                          widget.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4A65), // Deep Blue Title
                          ),
                         ),
                       ),
                       if (widget.isDelivery)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             color: const Color(0xFFE0F2F1), // Light Teal
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: const Text('Siap Antar', style: TextStyle(fontSize: 10, color: Color(0xFF00695C), fontWeight: FontWeight.bold)),
                         ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (widget.openingHours != null && widget.openingHours!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: _isHovered ? const Color(0xFF0A4A65) : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.openingHours!,
                          style: TextStyle(
                            fontSize: 12, 
                            color: _isHovered ? const Color(0xFF0A4A65) : Colors.grey,
                            fontWeight: _isHovered ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

