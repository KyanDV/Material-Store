// lib/owner/register_store_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RegisterStoreScreen extends StatefulWidget {
  const RegisterStoreScreen({super.key});

  @override
  State<RegisterStoreScreen> createState() => _RegisterStoreScreenState();
}

class _RegisterStoreScreenState extends State<RegisterStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  final Completer<GoogleMapController> _mapController = Completer();

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-6.200000, 106.816666), // Default Jakarta
    zoom: 12.0,
  );

  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isLoading = false;
  String _mapAddressLoadingText = '';

  @override
  void initState() {
    super.initState();
    _initializeMapToCurrentUserLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _initializeMapToCurrentUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateLocation(_kInitialPosition.target, moveMap: false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _updateLocation(LatLng(position.latitude, position.longitude), moveMap: true);
    } catch (e) {
      _updateLocation(_kInitialPosition.target, moveMap: false);
    }
  }

  // Fungsi _updateLocation disederhanakan, tanpa parameter poiName
  void _updateLocation(LatLng latLng, {bool moveMap = true, bool getAddress = true}) async {
    if (!mounted) return;

    setState(() {
      _selectedLocation = latLng;
      _mapAddressLoadingText = getAddress ? 'Mencari alamat...' : 'Lokasi dipilih.';
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: latLng,
          infoWindow: const InfoWindow(title: 'Lokasi Toko'),
          draggable: true,
          onDragEnd: (newPosition) {
            _updateLocation(newPosition, getAddress: true);
          },
        )
      };
    });

    if (moveMap && _mapController.isCompleted) {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 17.0),
      ));
    }

    if (getAddress) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);

        if (mounted && placemarks.isNotEmpty) {
          Placemark p = placemarks[0];
          String address = [p.street, p.subLocality, p.locality, p.subAdministrativeArea, p.postalCode]
              .where((s) => s != null && s.isNotEmpty).join(', ');

          setState(() {
            _addressController.text = address;
            _mapAddressLoadingText = 'Alamat ditemukan.';
            
            // Auto-fill Store Name - relaxed logic
            // Use 'name' from placemark if it exists. 
            // Often 'name' is the building name or business name.
            if (p.name != null && p.name!.isNotEmpty) {
               // Only overwrite if currently empty or auto-filled
               if (_nameController.text.isEmpty || _nameController.text == p.street) {
                 _nameController.text = p.name!;
               }
            }
          });
        } else if (mounted) {
          setState(() {
            _addressController.text = '';
            _mapAddressLoadingText = 'Tidak ada alamat yang ditemukan (Coba geser sedikit).';
          });
        }
      } catch (e) {
        if (mounted) {
          // Fallback if geocoding fails (e.g. quota exceeded or network error)
          setState(() => _mapAddressLoadingText = 'Gagal memuat alamat: ${e.toString()}');
        }
      }
    }
  }








  Future<void> _registerStore() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data dan pilih lokasi di peta.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('stores').insert({
        'id': user.id, // Enforce 1 store per user (PK = User ID)
        'storeName': _nameController.text,
        'contactInfo': _contactController.text,
        'address': _addressController.text,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toko berhasil didaftarkan!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String message = 'Gagal mendaftarkan toko: $e';
        if (e.toString().contains('duplicate key')) {
          message = 'Anda sudah memiliki toko terdaftar.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftarkan Toko Anda'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Toko'),
                  validator: (v) => v!.isEmpty ? 'Nama toko tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(labelText: 'Info Kontak (No. HP/WA)'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Kontak tidak boleh kosong' : null,
                ),
                const SizedBox(height: 24),
                const Text('Pilih Lokasi & Alamat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                Container(
                  height: 300,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: GoogleMap(
                    initialCameraPosition: _kInitialPosition,
                    onMapCreated: (GoogleMapController controller) {
                      if (!_mapController.isCompleted) {
                        _mapController.complete(controller);
                      }
                    },
                    onTap: (LatLng position) {
                      _updateLocation(position);
                    },
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Alamat Lengkap Toko',
                    helperText: _mapAddressLoadingText,
                  ),
                  validator: (v) => v!.isEmpty ? 'Alamat tidak boleh kosong' : null,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _registerStore, child: const Text('Daftarkan Toko')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}