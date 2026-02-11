// lib/owner/edit_store_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_store/services/geocoding_service.dart';


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

  // Operational Data
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 17, minute: 0);
  String _startDay = 'Senin';
  String _endDay = 'Jumat';
  final List<String> _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  
  bool _isDelivery = false;


  
  bool _isLoading = true;
  
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
    super.dispose();
  }

  Future<void> _selectTime(bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
      
      // Parse Opening Hours: "Senin - Jumat, 08:00 - 17:00"
      String opHours = data['opening_hours'] ?? '';
      if (opHours.isNotEmpty && opHours.contains(',') && opHours.contains('-')) {
        try {
          final parts = opHours.split(','); // ["Senin - Jumat", " 08:00 - 17:00"]
          if (parts.length == 2) {
             final dayPart = parts[0].trim();
             final timePart = parts[1].trim();
             
             final daySplit = dayPart.split('-');
             if (daySplit.length == 2) {
                String sDay = daySplit[0].trim();
                String eDay = daySplit[1].trim();
                if (_days.contains(sDay)) _startDay = sDay;
                if (_days.contains(eDay)) _endDay = eDay;
             }

             final timeSplit = timePart.split('-');
             if (timeSplit.length == 2) {
                final startT = timeSplit[0].trim().split(':');
                final endT = timeSplit[1].trim().split(':');
                if (startT.length == 2) _openTime = TimeOfDay(hour: int.parse(startT[0]), minute: int.parse(startT[1]));
                if (endT.length == 2) _closeTime = TimeOfDay(hour: int.parse(endT[0]), minute: int.parse(endT[1]));
             }
          }
        } catch (_) {
          debugPrint('Error parsing opening hours, using defaults');
        }
      }
      _isDelivery = data['is_delivery'] ?? false;
      _currentImageUrl = data['imageUrl'];
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
       final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
       
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





  Future<void> _updateStore() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data.')),
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

      double? lat;
      double? lng;
      try {
        final coords = await GeocodingService.getCoordinatesFromAddress(_addressController.text);
        if (coords != null) {
          lat = coords['latitude'];
          lng = coords['longitude'];
          debugPrint('Geocoding success: lat=$lat, lng=$lng');
        }
      } catch (e) {
        debugPrint('Geocoding failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Peringatan: Gagal mendapatkan koordinat lokasi. Jarak tidak akan ditampilkan.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await Supabase.instance.client.from('stores').update({
        'storeName': _nameController.text,
        'contactInfo': _contactController.text,
        'address': _addressController.text,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        'opening_hours': '$_startDay - $_endDay, ${_formatTime(_openTime)} - ${_formatTime(_closeTime)}',
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
                const SizedBox(height: 16),
                
                 // Hari Operasional
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _startDay,
                        decoration: const InputDecoration(labelText: 'Dari Hari'),
                        items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) => setState(() => _startDay = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _endDay,
                        decoration: const InputDecoration(labelText: 'Sampai Hari'),
                        items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) => setState(() => _endDay = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Jam Operasional
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Jam Buka', suffixIcon: Icon(Icons.access_time)),
                          child: Text(_formatTime(_openTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Jam Tutup', suffixIcon: Icon(Icons.access_time)),
                          child: Text(_formatTime(_closeTime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Siap Antar Barang?', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Aktifkan jika toko Anda menyediakan layanan pengiriman.', style: TextStyle(color: Colors.black87)),
                  value: _isDelivery,
                  onChanged: (val) => setState(() => _isDelivery = val),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Lengkap Toko',
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