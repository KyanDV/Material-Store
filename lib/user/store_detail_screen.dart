// lib/user/store_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {

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
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       data['imageUrl'] != null
                          ? CachedNetworkImage(
                              imageUrl: data['imageUrl']!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.grey[300]),
                              errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.store, size: 80, color: Colors.grey),
                            ),
                      // Gradient overlay for better text visibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                       const Divider(),
                       _buildInfoTile(
                         icon: Icons.access_time,
                         title: 'Jam Operasional',
                         subtitle: data['opening_hours'] ?? 'Jam operasional tidak tersedia',
                       ),
                       const Divider(),
                       _buildInfoTile(
                         icon: Icons.local_shipping,
                         title: 'Layanan Antar',
                         subtitle: (data['is_delivery'] == true) ? 'Tersedia' : 'Tidak Tersedia',
                       ),
                       const SizedBox(height: 24),
                       // Buttons (Direction etc)
                       Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.star_rate_rounded, color: Colors.white),
                              label: const Text('Rating & Review', style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                 final String query = Uri.encodeComponent('${data['storeName']} ${data['address']}');
                                 _launchURL('https://www.google.com/maps/search/?api=1&query=$query');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat, color: Colors.white),
                              label: const Text('Hubungi', style: TextStyle(color: Colors.white)),
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
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          var productData = productSnapshot.data![index];
                          String? imageUrl = productData['imageUrl'];
                          String price = 'Rp ${(productData['price'] as num?)?.toStringAsFixed(0) ?? '0'}';
                          String unit = productData['unit'] ?? '';
                          String displayPrice = unit.isNotEmpty ? '$price / $unit' : price;

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                if (imageUrl != null && imageUrl.isNotEmpty) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: const EdgeInsets.all(16), // Maximize space
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            height: 400, // Fixed height or adjust as needed, or remove for auto
                                            constraints: const BoxConstraints(maxHeight: 600, minHeight: 300),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: Colors.white,
                                            ),
                                            padding: const EdgeInsets.all(2),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: InteractiveViewer(
                                                panEnabled: true,
                                                minScale: 0.5,
                                                maxScale: 4.0,
                                                child: CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  fit: BoxFit.contain,
                                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                                  errorWidget: (context, url, error) => const Icon(Icons.error, size: 50),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -10,
                                            right: -10,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.close, color: Colors.black),
                                                onPressed: () => Navigator.of(context).pop(),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Gambar tidak tersedia untuk produk ini.')),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Small Image
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        image: imageUrl != null
                                            ? DecorationImage(image: CachedNetworkImageProvider(imageUrl), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: imageUrl == null
                                          ? Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 24))
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productData['name'] ?? 'Tanpa Nama',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            displayPrice,
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
