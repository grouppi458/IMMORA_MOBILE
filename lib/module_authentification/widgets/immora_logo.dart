import 'package:flutter/material.dart';

/// Logo IMMORA dans une carte blanche arrondie.
class ImmoraLogo extends StatelessWidget {
  const ImmoraLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Image.asset(
        'assets/images/logo.png',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
