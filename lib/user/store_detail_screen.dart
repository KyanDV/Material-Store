// lib/user/store_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- 1. IMPORT PACKAGE

class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Toko'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('stores').doc(widget.storeId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Toko tidak ditemukan.'));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          var location = data['location'] as GeoPoint;
          final LatLng storePosition = LatLng(location.latitude, location.longitude);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ... (Bagian Peta dan Info Toko tidak berubah)
                SizedBox(
                  height: 250,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: storePosition,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) {
                      if (!_mapController.isCompleted) {
                        _mapController.complete(controller);
                      }
                    },
                    markers: {
                      Marker(
                        markerId: MarkerId(widget.storeId),
                        position: storePosition,
                        infoWindow: InfoWindow(title: data['storeName'] ?? 'Lokasi Toko'),
                      ),
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['storeName'] ?? 'Nama Toko Tidak Tersedia',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.location_on,
                        title: 'Alamat',
                        subtitle: data['address'] ?? 'Alamat tidak tersedia',
                      ),
                      const Divider(),
                      _buildInfoTile(
                        icon: Icons.phone,
                        title: 'Kontak',
                        subtitle: data['contactInfo'] ?? 'Kontak tidak tersedia',
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.directions),
                              label: const Text('Arahkan'),
                              onPressed: () {
                                _launchURL('https://www.google.com/maps/search/?api=1&query=${storePosition.latitude},${storePosition.longitude}');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat),
                              label: const Text('Hubungi'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () {
                                final contact = data['contactInfo'] as String?;
                                if (contact != null) {
                                  final whatsappNumber = contact.replaceAll(RegExp(r'[^0-9]'),'').replaceFirst(RegExp(r'^0'), '62');
                                  _launchURL('https://wa.me/$whatsappNumber');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Katalog Produk',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stores')
                      .doc(widget.storeId)
                      .collection('products')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, productSnapshot) {
                    if (productSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!productSnapshot.hasData || productSnapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                        child: Center(child: Text('Toko ini belum memiliki produk di katalog.')),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: productSnapshot.data!.docs.length,
                      separatorBuilder: (context, index) => const Divider(indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        var productData = productSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                        String? imageUrl = productData['imageUrl'];
                        String price = 'Rp ${productData['price']?.toStringAsFixed(0) ?? '0'}';
                        String unit = productData['unit'] ?? '';
                        String displayPrice = unit.isNotEmpty ? '$price / $unit' : price;

                        return ListTile(
                          leading: imageUrl != null
                              ? SizedBox(
                            width: 60,
                            height: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              // --- 2. GANTI WIDGET DI SINI ---
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2.0),
                                ),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                              : const SizedBox(width: 60, height: 60, child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
                          title: Text(productData['name'] ?? 'Tanpa Nama'),
                          trailing: Text(
                            displayPrice,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}