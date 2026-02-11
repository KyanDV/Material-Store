import 'package:flutter/material.dart';
import 'package:material_store/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Ganti dengan URL dan Anon Key dari Supabase Project Anda
  await Supabase.initialize(
    url: 'https://gilsfhprotxslmqpofeq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpbHNmaHByb3R4c2xtcXBvZmVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNDc0NjcsImV4cCI6MjA4MzYyMzQ2N30.wObphgptgUcI3RzmC7VorcmOm0e-hWC36qYsx0yQTBg',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material Store',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD3C389),
          brightness: Brightness.light,
          primary: const Color(0xFFD3C389),
          secondary: const Color(0xFFD3C389),
          surface: Colors.white,
          onSurface: const Color(0xFF0A4A65),
          background: const Color(0xFFFEFEFF),
          onBackground: const Color(0xFF0A4A65),
        ),
        scaffoldBackgroundColor: const Color(0xFFFEFEFF),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFF0A4A65), fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFF0A4A65)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF0A4A65)),
          bodyMedium: TextStyle(color: Color(0xFF0A4A65)),
          titleLarge: TextStyle(color: Color(0xFF0A4A65), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF0A4A65), fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          hintStyle: TextStyle(color: const Color(0xFF0A4A65).withOpacity(0.5)),
          labelStyle: const TextStyle(color: Color(0xFF0A4A65)),
          prefixIconColor: const Color(0xFF0A4A65),
          suffixIconColor: const Color(0xFF0A4A65),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD3C389), width: 2),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Gunakan AuthGate sebagai home
    );
  }
}