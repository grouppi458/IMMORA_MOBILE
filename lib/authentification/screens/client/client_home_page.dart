import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('IMMORA'),
      ),
      body: const Center(child: Text('Client Home')),
    );
  }
}
