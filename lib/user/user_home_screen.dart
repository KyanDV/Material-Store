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
              title: const Text('Pilih Lokasi Pengiriman'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Cari Alamat (Jalan, Kota)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                             // Panggil fungsi search di parent widget, tapi update state dialog jika perlu
                             _searchLocationOSM(addressController.text).then((_) {
                               setStateDialog(() {}); // Refresh map di dialog
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
                           // Allow tap to pin
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
      appBar: AppBar(
        title: const Text('KANG JATI'),
        actions: [

          InkWell(
            onTap: _showManualLocationDialog,
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    _addressName,
                    style: const TextStyle(color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
              ],
            ),
          ),
          const Spacer(), // Spacer agar tombol login/toko ke kanan (atau gunakan MainAxisAlignment di Row parent jika perlu)
          
          StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = Supabase.instance.client.auth.currentSession;
              
              // Jika sudah login, tampilkan ikon Toko
              if (session != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const OwnerHomeScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Icon(Icons.store, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Toko', 
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          await Supabase.instance.client.auth.signOut();
                        },
                        icon: const Icon(Icons.logout, color: Colors.black),
                        tooltip: 'Keluar',
                      ),
                    ],
                  ),
                );
              }

              // Jika belum login, tampilkan tombol Masuk & Daftar
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Masuk'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                         Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Daftarkan Toko'),
                    ),
                  ],
                ),
              );
            },
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
                  fillColor: Theme.of(context).cardColor,
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
                    } else if (_currentLocation == null) {
                       distanceText = 'Lokasi Anda?';
                    } else {
                       distanceText = 'Lokasi Toko?';
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
    final Color hoverColor = const Color(0xFFD3C389); // Gold
    final Color defaultColor = const Color(0xFF0A4A65); // Dark Blue
    final Color primaryColor = Theme.of(context).primaryColor;
    
    // Dynamic Text Color based on Hover State
    final Color textColor = _isHovered ? const Color(0xFF0A4A65) : Colors.white;
    final Color iconColor = _isHovered ? const Color(0xFF0A4A65) : Colors.white70;

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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: TextStyle(color: textColor, fontSize: 13),
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
                            color: _isHovered ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: iconColor),
                              const SizedBox(width: 4),
                              Text(widget.openingHours!, style: TextStyle(fontSize: 11, color: textColor)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // Distance text removed as per request
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

