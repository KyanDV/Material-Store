// lib/owner/register_store_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';

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
  
  // Bank Controllers
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();

  // Files
  XFile? _nibFile;
  XFile? _npwpFile;
  XFile? _deedFile;
  
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (type == 'nib') _nibFile = image;
        if (type == 'npwp') _npwpFile = image;
        if (type == 'deed') _deedFile = image;
      });
    }
  }

  Future<String?> _uploadFile(XFile file, String folderName) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$folderName/$fileName';

      await Supabase.instance.client.storage
          .from('store_documents')
          .uploadBinary(
            filePath, 
            bytes, 
            fileOptions: FileOptions(contentType: file.mimeType ?? 'image/$fileExt'),
          );

      return Supabase.instance.client.storage
          .from('store_documents')
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _registerStore() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data.')),
      );
      return;
    }
    
    // Validate Files
    if (_nibFile == null || _npwpFile == null || _deedFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap unggah semua dokumen pendukung.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Cek Duplikasi Toko (Nama ATAU Alamat)
      final nameToCheck = _nameController.text.trim();
      final addressToCheck = _addressController.text.trim();

      // Cek Nama
      final checkName = await Supabase.instance.client
          .from('stores')
          .select('id')
          .eq('storeName', nameToCheck)
          .maybeSingle();

      // Cek Alamat
      final checkAddress = await Supabase.instance.client
          .from('stores')
          .select('id')
          .eq('address', addressToCheck)
          .maybeSingle();

      if (checkName != null || checkAddress != null) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: ${checkName != null ? 'Nama Toko' : 'Alamat Toko'} sudah terdaftar oleh pengguna lain.'),
              backgroundColor: Colors.red
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. Upload Dokumen
      // Upload Documents
      final nibUrl = await _uploadFile(_nibFile!, user.id);
      final npwpUrl = await _uploadFile(_npwpFile!, user.id);
      final deedUrl = await _uploadFile(_deedFile!, user.id);

      if (nibUrl == null || npwpUrl == null || deedUrl == null) {
        throw 'Gagal mengunggah dokumen.';
      }

      // 3. Geocoding Address
      double? lat;
      double? lng;
      try {
        List<Location> locations = await locationFromAddress(_addressController.text);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (e) {
        debugPrint('Geocoding failed: $e');
        // Continue registration even if geocoding fails, user can update later
      }

      await Supabase.instance.client.from('stores').insert({
        'id': user.id, // Enforce 1 store per user (PK = User ID)
        'storeName': _nameController.text,
        'contactInfo': _contactController.text,
        'address': _addressController.text,
        'latitude': lat,
        'longitude': lng,
        'bank_name': _bankNameController.text,
        'bank_account_number': _bankAccountController.text,
        'nib_url': nibUrl,
        'npwp_url': npwpUrl,
        'deed_url': deedUrl,
        'opening_hours': '-', // Default
        'is_delivery': false, // Default
        'status': 'Pending', // Default status
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toko berhasil didaftarkan! Menunggu verifikasi admin.')));
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Lengkap Toko'
                  ),
                  validator: (v) => v!.isEmpty ? 'Alamat tidak boleh kosong' : null,
                  maxLines: 3,
                ),

                 const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Divider(),
                ),

                const Text('Informasi Bank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(labelText: 'Nama Bank'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _bankAccountController,
                        decoration: const InputDecoration(labelText: 'No. Rekening'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                 const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Divider(),
                ),

                const Text('Dokumen Legalitas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Unggah foto dokumen pendukung (jpg/png)', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                
                _buildFilePicker('Nomor Induk Berusaha (NIB)', _nibFile, 'nib'),
                _buildFilePicker('NPWP', _npwpFile, 'npwp'),
                _buildFilePicker('Akta Pendirian Perusahaan', _deedFile, 'deed'),

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
  Widget _buildFilePicker(String label, XFile? file, String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        subtitle: Text(file != null ? 'File terpilih: ${file.name}' : 'Belum ada file'),
        trailing: Icon(file != null ? Icons.check_circle : Icons.upload_file, color: file != null ? Colors.green : Colors.grey),
        onTap: () => _pickImage(type),
      ),
    );
  }
}