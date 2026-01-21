// lib/user/store_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      body: FutureBuilder<Map<String, dynamic>>(
        future: Supabase.instance.client.from('stores').select().eq('id', widget.storeId).single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Toko tidak ditemukan.'));
          }

          var data = snapshot.data!;
          final LatLng storePosition = LatLng(
            (data['latitude'] as num?)?.toDouble() ?? 0.0,
            (data['longitude'] as num?)?.toDouble() ?? 0.0,
          );

          return CustomScrollView(
            slivers: [
              // 1. Collapsing Map Header
              SliverAppBar(
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(data['storeName'] ?? 'Detail Toko', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                  background: GoogleMap(
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
                    liteModeEnabled: false, // Better interaction
                    zoomControlsEnabled: false,
                  ),
                ),
              ),
              // 2. Store Info
              SliverToBoxAdapter(
                child: Padding(
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
                       // Buttons (Direction etc)
                       Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.directions, color: Colors.white),
                              label: const Text('Arahkan', style: TextStyle(color: Colors.black87)),
                              onPressed: () {
                                _launchURL('https://www.google.com/maps/search/?api=1&query=${storePosition.latitude},${storePosition.longitude}');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat, color: Colors.white),
                              label: const Text('Hubungi', style: TextStyle(color: Colors.black87)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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
                      const SizedBox(height: 12),
                       SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                             final String query = Uri.encodeComponent('${data['storeName']} ${data['address']}');
                             _launchURL('https://www.google.com/maps/search/?api=1&query=$query');
                          },
                          icon: const Icon(Icons.star_rate_rounded, color: Colors.amber),
                          label: const Text('Lihat Rating & Review di Google Maps', style: TextStyle(color: Colors.black87)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Katalog Produk',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // 3. Product Grid
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('products')
                    .stream(primaryKey: ['id'])
                    .eq('store_id', widget.storeId)
                    .order('name', ascending: true),
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                  }
                  if (!productSnapshot.hasData || productSnapshot.data!.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                        child: Center(child: Text('Toko ini belum memiliki produk di katalog.')),
                      ),
                    );
                  }
                  
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75, // Taller for image + text
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          var productData = productSnapshot.data![index];
                          String? imageUrl = productData['imageUrl'];
                          String price = 'Rp ${(productData['price'] as num?)?.toStringAsFixed(0) ?? '0'}';
                          String unit = productData['unit'] ?? '';
                          String displayPrice = unit.isNotEmpty ? '$price / $unit' : price;

                          return Card(
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      image: imageUrl != null
                                          ? DecorationImage(image: CachedNetworkImageProvider(imageUrl), fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: imageUrl == null
                                        ? Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 40))
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productData['name'] ?? 'Tanpa Nama',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        displayPrice,
                                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: productSnapshot.data!.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
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
                Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
