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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Gunakan AuthGate sebagai home
    );
  }
}