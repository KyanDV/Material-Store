// lib/owner/edit_store_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EditStoreScreen extends StatefulWidget {
  final String storeId;
  const EditStoreScreen({super.key, required this.storeId});

  @override
  State<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  final Completer<GoogleMapController> _mapController = Completer();

  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isLoading = true; // Mulai dengan loading untuk fetch data
  String _mapAddressLoadingText = '';

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil data toko yang sudah ada
  Future<void> _fetchStoreData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('stores').doc(widget.storeId).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        _nameController.text = data['storeName'] ?? '';
        _contactController.text = data['contactInfo'] ?? '';
        _addressController.text = data['address'] ?? '';

        if (data['location'] is GeoPoint) {
          GeoPoint point = data['location'];
          _selectedLocation = LatLng(point.latitude, point.longitude);
          _updateLocation(_selectedLocation!, moveMap: true, getAddress: false);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data toko: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateLocation(LatLng latLng, {bool moveMap = true, bool getAddress = true}) async {
    if (!mounted) return;

    setState(() {
      _selectedLocation = latLng;
      _mapAddressLoadingText = getAddress ? 'Mencari alamat...' : _mapAddressLoadingText;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: latLng,
          infoWindow: const InfoWindow(title: 'Lokasi Toko'),
          draggable: true,
          onDragEnd: (newPosition) => _updateLocation(newPosition),
        )
      };
    });

    if (moveMap) {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15.0),
      ));
    }

    if (getAddress) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
        if (mounted && placemarks.isNotEmpty) {
          Placemark p = placemarks[0];
          String address = [p.street, p.subLocality, p.locality, p.subAdministrativeArea, p.postalCode]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
          setState(() {
            _addressController.text = address;
            _mapAddressLoadingText = 'Alamat ditemukan.';
          });
        }
      } catch (e) {
        if (mounted) setState(() => _mapAddressLoadingText = 'Gagal mendapatkan alamat otomatis.');
      }
    }
  }

  // Fungsi untuk menyimpan perubahan
  Future<void> _updateStore() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data dan pilih lokasi di peta.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('stores').doc(widget.storeId).update({
        'storeName': _nameController.text,
        'contactInfo': _contactController.text,
        'address': _addressController.text,
        'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toko berhasil diperbarui!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui toko: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Toko'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ?? const LatLng(-6.2, 106.8),
                      zoom: 14,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      if (!_mapController.isCompleted) _mapController.complete(controller);
                    },
                    onTap: (LatLng latLng) => _updateLocation(latLng),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
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
                ElevatedButton(onPressed: _updateStore, child: const Text('Simpan Perubahan')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}