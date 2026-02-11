import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_store/auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to AuthGate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000), // Smooth transition time
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A4A65), // Changed to Dark Blue for better contrast
      body: Center(
        child: Hero(
          tag: 'app_logo',
          child: Image.asset(
            'assets/images/Logo_KANG_JATI_Transparan.png',
            width: 200, // Initial size
            height: 200,
          ),
        ),
      ),
    );
  }
}
