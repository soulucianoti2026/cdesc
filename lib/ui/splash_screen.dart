import 'package:flutter/material.dart';

/// Shared opening identity, also used while the repository initializes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087443),
            Color(0xFF68B58A),
            Colors.white,
            Color(0xFFF5C7CB),
            Color(0xFFCE3045),
          ],
          stops: [0, .28, .53, .76, 1],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: 144,
                    height: 144,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Eleição CDE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF124C36),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SANTA CATARINA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF124C36),
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF087443),
                    semanticsLabel: 'Carregando aplicativo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
