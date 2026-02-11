
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  /// Mendapatkan koordinat (latitude, longitude) dari alamat.
  /// Mencoba menggunakan paket geocoding native terlebih dahulu.
  /// Jika gagal (misalnya di Web/Windows), mencoba menggunakan OpenStreetMap API.
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      // 1. Coba Native Geocoding (Google/iOS Services)
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        debugPrint('Geocoding native success');
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
    } catch (e) {
      debugPrint('Native geocoding failed: $e. Falling back to OSM.');
    }

    // 2. Fallback ke OpenStreetMap (Nominatim) untuk Web/Windows
    return await _getCoordinatesFromOSM(address);
  }

  static Future<Map<String, double>?> _getCoordinatesFromOSM(String address) async {
    try {
      final query = Uri.encodeComponent(address);
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'MaterialStoreApp/1.0 (contact@materialstore.com)',
        'Accept': 'application/json',
      });

      debugPrint('OSM Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // debugPrint('OSM Response Body: ${response.body}'); // Commented out to reduce noise
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          debugPrint('OSM geocoding success: $lat, $lon');
          return {
            'latitude': lat, 
            'longitude': lon
          };
        } else {
          debugPrint('OSM returned empty list for address: $address');
          
          // --- RETRY LOGIC for Detailed Addresses ---
          // Jika alamat lengkap gagal (contoh: ada nomor rumah yg tidak terdata),
          // Coba cari dengan format yang lebih umum (misal: "Jalan X, Kota Y")
          if (address.contains(',')) {
             final parts = address.split(',');
             // Jika elemennya banyak (misal: Jalan, Kelurahan, Kecamatan, Kota, Prov)
             // Ambil elemen pertama (Jalan) dan elemen yang mengandung 'Surabaya' atau kota lain, atau 2 elemen terakhir.
             
             if (parts.length > 2) {
               // Strategi: Ambil bagian pertama (Jalan) + Bagian yang 'mungkin' Kota (biasanya index ke-3 atau ke-4)
               // Simple retry: Coba 2 bagian pertama saja + bagian terakhir (Provinsi/Kota)
               // Atau lebih simpel: Ambil bagian pertama dan bagian sebelum terakhir
               
               // Coba Retry 1: Hapus bagian kedua (biasanya kelurahan/kecamatan yang detail)
               String simplifiedAddress = '${parts.first}, ${parts.last}'; // "Jl. X, Jawa Timur" might be too broad but safer
               
               // Coba cari "Kota" atau "Kabupaten" di parts
               String? cityPart;
               for (var part in parts) {
                 if (part.toLowerCase().contains('kota') || part.toLowerCase().contains('surabaya') || part.toLowerCase().contains('jakarta')) {
                   cityPart = part;
                   break;
                 }
               }
               
               if (cityPart != null) {
                 simplifiedAddress = '${parts.first}, $cityPart';
               }
               
               debugPrint('Retrying with simplified address (Level 1): $simplifiedAddress');
               // Recursive call with simplified address
               if (simplifiedAddress != address) {
                 final result = await _getCoordinatesFromOSM(simplifiedAddress);
                 if (result != null) return result;
                 
                 // --- RETRY LOGIC Level 2 (Hyper Simplified) ---
                 // Jika masih gagal, coba buang nomor rumah (biasanya ini bikin gagal di OSM)
                 // "Jl. Indrakila No.7, Surabaya" -> "Jl. Indrakila, Surabaya"
                 // Regex: remove "No.X", "No X", digits, etc.
                 final superSimple = simplifiedAddress.replaceAll(RegExp(r'No\.?\s*\d+', caseSensitive: false), '')
                                                      .replaceAll(RegExp(r'\d+'), '') // Remove remaining digits if unsafe
                                                      .replaceAll(RegExp(r'\s+'), ' ') // Fix spaces
                                                      .replaceAll(' ,', ',')
                                                      .trim();
                                                      
                 debugPrint('Retrying with simplified address (Level 2): $superSimple');
                 if (superSimple != simplifiedAddress) {
                    return await _getCoordinatesFromOSM(superSimple);
                 }
               }
             }
          }
        }
      } else {
        debugPrint('OSM Request Failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('OSM geocoding error: $e');
    }
    return null;
  }
}
