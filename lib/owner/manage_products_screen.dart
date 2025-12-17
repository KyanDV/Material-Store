// lib/owner/manage_products_screen.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  Future<String?> _uploadImage(Uint8List imageData, String productId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('product_images')
          .child(widget.storeId)
          .child('$productId.jpg');

      await storageRef.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
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
      final collection = FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('products');

      DocumentReference docRef = (docId == null) ? collection.doc() : collection.doc(docId);

      String? imageUrl;
      if (imageBytes != null) {
        imageUrl = await _uploadImage(imageBytes, docRef.id);
        if (imageUrl == null) return false;
      }

      final productData = {
        'name': name.trim(),
        'price': price,
        'unit': unit.trim(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      if (docId == null) {
        await docRef.set(productData);
      } else {
        await docRef.update(productData);
      }

      if (mounted) {
        final successMessage = (docId == null) ? 'Produk berhasil ditambahkan.' : 'Produk berhasil diperbarui.';
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

  void _showProductDialog({DocumentSnapshot? productDoc}) {
    final productNameController = TextEditingController();
    final productPriceController = TextEditingController();
    final productUnitController = TextEditingController();
    Uint8List? _selectedImageBytes;
    String? _existingImageUrl;
    bool isSaving = false;
    String dialogTitle = 'Tambah Produk Baru';

    if (productDoc != null) {
      dialogTitle = 'Edit Produk';
      var data = productDoc.data() as Map<String, dynamic>;
      productNameController.text = data['name'] ?? '';
      productPriceController.text = (data['price'] as num?)?.toStringAsFixed(0) ?? '';
      productUnitController.text = data['unit'] ?? '';
      _existingImageUrl = data['imageUrl'];
    }

    Future<void> _pickImage() async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
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
                      docId: productDoc?.id,
                    );

                    if (dialogContext.mounted) {
                      if (success) {
                        Navigator.of(dialogContext).pop();
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stores')
            .doc(widget.storeId)
            .collection('products')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Gagal memuat produk.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada produk. Tekan + untuk menambah.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String? imageUrl = data['imageUrl'];
              String price = 'Rp ${(data['price'] as num?)?.toStringAsFixed(0) ?? '0'}';
              String unit = data['unit'] ?? '';

              String displayPrice = unit.isNotEmpty ? '$price / $unit' : price;

              return ListTile(
                leading: imageUrl != null
                    ? SizedBox(
                  width: 50,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        return progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, color: Colors.grey);
                      },
                    ),
                  ),
                )
                    : const SizedBox(width: 50, height: 50, child: Icon(Icons.image_not_supported, color: Colors.grey)),
                title: Text(data['name'] ?? 'Tanpa Nama'),
                subtitle: Text(displayPrice),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showProductDialog(productDoc: doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProduct(doc.id),
                    ),
                  ],
                ),
              );
            }).toList(),
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
                final docRef = FirebaseFirestore.instance
                    .collection('stores')
                    .doc(widget.storeId)
                    .collection('products')
                    .doc(productId);
                await docRef.delete();

                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('product_images')
                    .child(widget.storeId)
                    .child('$productId.jpg');
                await storageRef.delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Produk berhasil dihapus.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (e is FirebaseException && e.code == 'object-not-found') {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produk berhasil dihapus (gambar tidak ditemukan).'), backgroundColor: Colors.green),
                    );
                  }
                } else if (mounted) {
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