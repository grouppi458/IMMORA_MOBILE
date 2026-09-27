import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum BannerType { error, success, info }

/// Encadré coloré avec icône (erreur, succès ou info).
class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.message, required this.type});

  final String message;
  final BannerType type;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (type) {
      BannerType.error => (AppColors.errorBg, AppColors.error, Icons.warning_amber_rounded),
      BannerType.success => (AppColors.successBg, AppColors.success, Icons.check_circle_outline),
      BannerType.info => (AppColors.infoBg, AppColors.primary, Icons.info_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: fg, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
