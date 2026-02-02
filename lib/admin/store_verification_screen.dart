import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> storeData;

  const StoreVerificationScreen({super.key, required this.storeData});

  @override
  State<StoreVerificationScreen> createState() => _StoreVerificationScreenState();
}

class _StoreVerificationScreenState extends State<StoreVerificationScreen> {
  bool _isLoading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('stores')
          .update({'status': status})
          .eq('id', widget.storeData['id']);

      if (mounted) {
        Navigator.pop(context); // Kembali ke dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toko berhasil ${status == 'Approved' ? 'disetujui' : 'ditolak'}'),
            backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Gagal mengubah status: $e')),
        );
         setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openDocument(String? url) async {
    if (url == null || url.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL dokumen tidak valid')));
       return;
    }
    
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka dokumen')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.storeData;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Toko')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Info Toko'),
            _buildInfoRow('Nama Toko', data['storeName']),
            _buildInfoRow('Alamat Toko', data['address']),
            _buildInfoRow('Kontak', data['contactInfo']),
            const Divider(height: 32),

            _buildSectionHeader('Info Bank'),
            _buildInfoRow('Bank', data['bank_name']),
            _buildInfoRow('No. Rekening', data['bank_account_number']),
            const Divider(height: 32),

             _buildSectionHeader('Dokumen Legalitas'),
             _buildDocButton('Lihat NIB', data['nib_url']),
             _buildDocButton('Lihat NPWP', data['npwp_url']),
             _buildDocButton('Lihat Akta Pendirian', data['deed_url']),
             
             const SizedBox(height: 32),

             if (_isLoading)
               const Center(child: CircularProgressIndicator())
             else if (data['status'] == 'Pending')
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton(
                       onPressed: () => _updateStatus('Rejected'),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.red,
                         side: const BorderSide(color: Colors.red),
                         padding: const EdgeInsets.symmetric(vertical: 16),
                       ),
                       child: const Text('TOLAK'),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: ElevatedButton(
                       onPressed: () => _updateStatus('Approved'),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.green,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                       ),
                       child: const Text('SETUJUI'),
                     ),
                   ),
                 ],
               )
             else 
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: data['status'] == 'Approved' ? Colors.green.shade50 : Colors.red.shade50,
                   border: Border.all(color: data['status'] == 'Approved' ? Colors.green : Colors.red),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(
                       data['status'] == 'Approved' ? Icons.check_circle : Icons.cancel,
                       color: data['status'] == 'Approved' ? Colors.green : Colors.red,
                     ),
                     const SizedBox(width: 8),
                     Text(
                       'Status: ${data['status'] == 'Approved' ? 'Disetujui' : 'Ditolak'}',
                       style: TextStyle(
                         fontSize: 18, 
                         fontWeight: FontWeight.bold,
                         color: data['status'] == 'Approved' ? Colors.green : Colors.red,
                       ),
                     ),
                   ],
                 ),
               )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey))),
          Expanded(child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDocButton(String label, String? url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.file_open),
        label: Text(label),
        onPressed: () => _openDocument(url),
        style: ElevatedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
