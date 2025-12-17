// lib/user/user_home_screen.dart

import 'dart:async';
import 'dart:ui' as ui; // Diperlukan untuk Canvas
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Diperlukan untuk ByteData
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_store/user/store_detail_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _currentLocation;
  String _loadingMessage = 'Mencari lokasi Anda...';

  Set<Marker> _markers = {};
  Set<Marker> _storeMarkers = {};

  // State untuk menyimpan ikon kustom
  BitmapDescriptor? _userLocationIcon;

  @override
  void initState() {
    super.initState();
    _setCustomMarkerIcon(); // Panggil fungsi untuk membuat ikon
    _initializeScreen();
  }

  // Fungsi untuk membuat ikon lingkaran biru secara dinamis
  Future<void> _setCustomMarkerIcon() async {
    // Ukuran diameter ikon diubah menjadi 50px agar lebih kecil
    final icon = await _createCustomMarkerBitmap(50);
    if (mounted) {
      setState(() {
        _userLocationIcon = icon;
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(int size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.blue;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size / 10 // Disesuaikan agar border tidak terlalu tebal
      ..style = PaintingStyle.stroke;

    // Gambar lingkaran luar (border putih)
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.2, borderPaint);
    // Gambar lingkaran dalam (biru)
    canvas.drawCircle(Offset(size / 2, size / 2), size / 3, paint);

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _initializeScreen() async {
    await _determinePosition();
    if (_currentLocation != null) {
      _listenToStoreUpdates();
    }
  }

  void _updateMarkers() {
    if (!mounted) return;
    setState(() {
      _markers.clear();
      _markers.addAll(_storeMarkers);

      // Gunakan ikon kustom jika sudah siap
      if (_currentLocation != null && _userLocationIcon != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: _currentLocation!,
            icon: _userLocationIcon!, // Gunakan ikon kustom
            anchor: const Offset(0.5, 0.5), // Penting agar ikon terpusat
            infoWindow: const InfoWindow(
              title: 'Lokasi Anda',
            ),
          ),
        );
      }
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => _loadingMessage = 'Layanan lokasi mati. Harap aktifkan GPS.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _loadingMessage = 'Izin lokasi ditolak. Menggunakan lokasi default.';
          _currentLocation = const LatLng(-6.200000, 106.816666);
          _updateMarkers();
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _loadingMessage = 'Izin lokasi ditolak permanen. Menggunakan lokasi default.';
        _currentLocation = const LatLng(-6.200000, 106.816666);
        _updateMarkers();
      });
      return;
    }

    try {
      if (!mounted) return;
      setState(() => _loadingMessage = 'Mendapatkan koordinat...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateMarkers();
        });
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 15.0),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMessage = 'Gagal mendapatkan lokasi. Menggunakan lokasi default.';
        _currentLocation = const LatLng(-6.200000, 106.816666);
        _updateMarkers();
      });
    }
  }

  void _listenToStoreUpdates() {
    FirebaseFirestore.instance.collection('stores').snapshots().listen((snapshot) {
      if (!mounted) return;

      Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data.containsKey('location') && data['location'] is GeoPoint) {
          var location = data['location'] as GeoPoint;
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(location.latitude, location.longitude),
              infoWindow: InfoWindow(
                title: data['storeName'] ?? 'Toko',
                snippet: 'Ketuk untuk melihat detail',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoreDetailScreen(storeId: doc.id),
                  ),
                );
              },
            ),
          );
        }
      }

      setState(() {
        _storeMarkers = newMarkers;
        _updateMarkers();
      });
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Toko Material'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Pilih Peran Lain',
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: 'Pusatkan ke Lokasi Saya',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout dari Akun',
          ),
        ],
      ),
      body: _currentLocation == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage),
          ],
        ),
      )
          : GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(target: _currentLocation!, zoom: 14),
        onMapCreated: (GoogleMapController controller) {
          if (!_mapController.isCompleted) {
            _mapController.complete(controller);
          }
        },
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}