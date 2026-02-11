// lib/owner/manage_products_screen.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// Gunakan 'dart:io' hanya jika bukan di web
import 'dart:io' if (kIsWeb) 'dart:html' as universal_io;

class ManageProductsScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const ManageProductsScreen({super.key, required this.storeId, required this.storeName});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('store_id', widget.storeId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat produk: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _uploadImage(Uint8List imageData, String productId) async {
    try {
      final path = 'product_images/${widget.storeId}/$productId.jpg';
      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(path, imageData, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final publicUrl = Supabase.instance.client.storage.from('images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah gambar: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<bool> _saveProduct({
    required String name,
    required String priceString,
    required String unit,
    Uint8List? imageBytes,
    String? docId,
  }) async {
    if (name.trim().isEmpty || priceString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan harga produk tidak boleh kosong.'), backgroundColor: Colors.orange),
      );
      return false;
    }
    final cleanedPrice = priceString.replaceAll(RegExp(r'[^0-9]'), '');
    final price = double.tryParse(cleanedPrice);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format harga tidak valid.'), backgroundColor: Colors.orange),
      );
      return false;
    }

    try {
      final productsTable = Supabase.instance.client.from('products');
      String currentId = docId ?? '';
      bool isNew = docId == null;

      // Data preparation
      final productData = {
        'store_id': widget.storeId,
        'name': name.trim(),
        'price': price,
        'unit': unit.trim(),
        'lastUpdatedAt': DateTime.now().toIso8601String(),
      };

      if (isNew) {
        // Insert and get ID
        final response = await productsTable.insert(productData).select().single();
        currentId = response['id'];
        // Note: We'll upload image next
      } else {
        // Update basic info first
        await productsTable.update(productData).eq('id', currentId);
      }

      // Handle Image Upload if exists
      if (imageBytes != null) {
        String? imageUrl = await _uploadImage(imageBytes, currentId);
        if (imageUrl != null) {
           await productsTable.update({'imageUrl': imageUrl}).eq('id', currentId);
        }
      }

      if (mounted) {
        final successMessage = isNew ? 'Produk berhasil ditambahkan.' : 'Produk berhasil diperbarui.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  void _showProductDialog({Map<String, dynamic>? productDoc}) {
    final productNameController = TextEditingController();
    final productPriceController = TextEditingController();
    final productUnitController = TextEditingController();
    Uint8List? _selectedImageBytes;
    String? _existingImageUrl;
    bool isSaving = false;
    String dialogTitle = 'Tambah Produk Baru';

    if (productDoc != null) {
      dialogTitle = 'Edit Produk';
      var data = productDoc;
      productNameController.text = data['name'] ?? '';
      productPriceController.text = (data['price'] as num?)?.toStringAsFixed(0) ?? '';
      productUnitController.text = data['unit'] ?? '';
      _existingImageUrl = data['imageUrl'];
    }

    Future<void> _pickImage() async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 600);
      if (pickedFile != null) {
        _selectedImageBytes = await pickedFile.readAsBytes();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget imageWidget;
            if (_selectedImageBytes != null) {
              imageWidget = Image.memory(_selectedImageBytes!, fit: BoxFit.cover);
            } else if (_existingImageUrl != null) {
              imageWidget = Image.network(_existingImageUrl!, fit: BoxFit.cover);
            } else {
              imageWidget = const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.grey),
                    Text('Pilih Gambar', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Text(dialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: isSaving ? null : () async {
                        await _pickImage();
                        setDialogState(() {});
                      },
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageWidget,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: productNameController,
                      decoration: const InputDecoration(labelText: 'Nama Produk'),
                      textCapitalization: TextCapitalization.words,
                      enabled: !isSaving,
                    ),
                    TextField(
                      controller: productPriceController,
                      decoration: const InputDecoration(labelText: 'Harga', prefixText: 'Rp '),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !isSaving,
                    ),
                    TextField(
                      controller: productUnitController,
                      decoration: const InputDecoration(
                        labelText: 'Per (Opsional)',
                        hintText: 'Contoh: sak, 500 gram, kg',
                      ),
                      textCapitalization: TextCapitalization.none,
                      enabled: !isSaving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                isSaving
                    ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : ElevatedButton(
                  onPressed: () async {
                    setDialogState(() => isSaving = true);

                    bool success = await _saveProduct(
                      name: productNameController.text,
                      priceString: productPriceController.text,
                      unit: productUnitController.text,
                      imageBytes: _selectedImageBytes,
                      docId: productDoc?['id'],
                    );

                    if (dialogContext.mounted) {
                      if (success) {
                        Navigator.of(dialogContext).pop();
                        _fetchProducts(); // Refresh list after save
                      } else {
                        setDialogState(() => isSaving = false);
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Katalog: ${widget.storeName}'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _products.isEmpty
              ? const Center(child: Text('Belum ada produk. Tekan + untuk menambah.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final data = _products[index];
                    String? imageUrl = data['imageUrl'];
                    String price = 'Rp ${(data['price'] as num?)?.toStringAsFixed(0) ?? '0'}';
                    String unit = data['unit'] ?? '';
                    String displayPrice = unit.isNotEmpty ? '$price / $unit' : price;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: imageUrl != null && imageUrl.isNotEmpty
                              ? SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: 50, height: 50, child: Icon(Icons.image_not_supported, color: Colors.grey)),
                          title: Text(data['name'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(displayPrice, style: const TextStyle(color: Colors.green)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProductDialog(productDoc: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent), // Red is fine for delete, or maybe Gold? Let's keep red for danger but maybe brighter?
                              onPressed: () => _deleteProduct(data['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        tooltip: 'Tambah Produk',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: const Text('Apakah Anda yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                // Delete from DB
                await Supabase.instance.client
                    .from('products')
                    .delete()
                    .eq('id', productId);

                // Delete from Storage (ignore error if not exists)
                final imagePath = 'product_images/${widget.storeId}/$productId.jpg';
                try {
                  await Supabase.instance.client.storage.from('images').remove([imagePath]);
                } catch (_) {}

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Produk berhasil dihapus.'), backgroundColor: Colors.green),
                  );
                  _fetchProducts(); // Refresh list after delete
                }
              } catch (e) {
                 if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus produk: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}