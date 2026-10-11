import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';

enum BannerType { error, success, info, warning }

/// Encadré coloré avec icône (erreur, succès, info ou avertissement).
/// [title] est affiché en gras au-dessus du message (bandeaux IA des maquettes).
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    required this.type,
    this.icon,
    this.title,
  });

  final String message;
  final BannerType type;

  /// Icône personnalisée (ex. cloche des rappels) ; sinon celle du type.
  final IconData? icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData defaultIcon) = switch (type) {
      BannerType.error => (AppColors.errorBg, AppColors.error, Icons.warning_amber_rounded),
      BannerType.success => (AppColors.successBg, AppColors.success, Icons.check_circle_outline),
      BannerType.info => (AppColors.infoBg, AppColors.primary, Icons.info_outline),
      BannerType.warning => (AppColors.warningBg, AppColors.warning, Icons.info_outline),
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
          Icon(icon ?? defaultIcon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: title == null
                ? Text(message, style: TextStyle(color: fg, fontSize: 12.5, height: 1.4))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!,
                          style: TextStyle(
                              color: fg, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(message,
                          style: TextStyle(color: fg, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
