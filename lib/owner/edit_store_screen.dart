// lib/owner/edit_store_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

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

  final _openingHoursController = TextEditingController();
  
  bool _isDelivery = false;

  final Completer<GoogleMapController> _mapController = Completer();

  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String _mapAddressLoadingText = '';
  
  Uint8List? _newImageBytes;
  String? _currentImageUrl;

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
    _openingHoursController.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreData() async {
    try {
      final data = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('id', widget.storeId)
          .single();

      _nameController.text = data['storeName'] ?? '';
      _contactController.text = data['contactInfo'] ?? '';
      _addressController.text = data['address'] ?? '';
      _openingHoursController.text = data['opening_hours'] ?? '';
      _isDelivery = data['is_delivery'] ?? false;
      _currentImageUrl = data['imageUrl'];

      if (data['latitude'] != null && data['longitude'] != null) {
        _selectedLocation = LatLng(data['latitude'], data['longitude']);
        _updateLocation(_selectedLocation!, moveMap: true, getAddress: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data toko: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
     try {
       final picker = ImagePicker();
       final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
       if (pickedFile != null) {
         final bytes = await pickedFile.readAsBytes();
         setState(() {
           _newImageBytes = bytes;
         });
       }
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
     }
  }

  Future<String?> _uploadStoreImage(Uint8List imageData) async {
    try {
      final path = 'store_images/${widget.storeId}/profile.jpg';
      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(path, imageData, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));

      return Supabase.instance.client.storage.from('images').getPublicUrl(path);
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload gambar toko: $e')));
      }
      return null;
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
       // Ensure controller is ready before moving
       if (_mapController.isCompleted) {
          final GoogleMapController controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 17.0),
          ));
       }
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



  Future<void> _updateStore() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data dan pilih lokasi di peta.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;
      if (_newImageBytes != null) {
        imageUrl = await _uploadStoreImage(_newImageBytes!);
        if (imageUrl == null) {
          setState(() => _isLoading = false);
          return; // Stop if upload failed
        }
      }

      await Supabase.instance.client.from('stores').update({
        'storeName': _nameController.text,
        'contactInfo': _contactController.text,
        'address': _addressController.text,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'opening_hours': _openingHoursController.text,
        'is_delivery': _isDelivery,
        if (imageUrl != null) 'imageUrl': imageUrl,
      }).eq('id', widget.storeId);

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
                // Store Image Picker
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                        image: _newImageBytes != null 
                            ? DecorationImage(image: MemoryImage(_newImageBytes!), fit: BoxFit.cover)
                            : (_currentImageUrl != null 
                                ? DecorationImage(image: NetworkImage(_currentImageUrl!), fit: BoxFit.cover) 
                                : null),
                      ),
                      child: (_newImageBytes == null && _currentImageUrl == null) 
                          ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey) 
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: Text('Ketuk gambar untuk mengubah', style: TextStyle(color: Colors.grey, fontSize: 12))),
                const SizedBox(height: 24),

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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openingHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Jam Operasional',
                    hintText: 'Contoh: 08:00 - 17:00'
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Siap Antar Barang?', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Aktifkan jika toko Anda menyediakan layanan pengiriman.', style: TextStyle(color: Colors.black87)),
                  value: _isDelivery,
                  onChanged: (val) => setState(() => _isDelivery = val),
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
                ElevatedButton(onPressed: _updateStore, child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.black87))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}