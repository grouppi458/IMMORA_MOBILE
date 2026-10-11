import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Affiche une photo de bien stockée dans /photos/ (path_provider).
/// Repli en dégradé si le fichier est absent (données de démo, web).
class PropertyPhotoView extends StatelessWidget {
  const PropertyPhotoView(this.path, {super.key, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(path, fit: fit, errorBuilder: _fallback);
    }
    final file = File(path);
    if (!file.existsSync()) return _fallback(context, null, null);
    return Image.file(file, fit: fit, errorBuilder: _fallback);
  }

  Widget _fallback(BuildContext context, Object? error, StackTrace? stack) => Container(
        decoration: const BoxDecoration(gradient: _placeholderGradient),
        child: const Icon(Icons.home_outlined, color: Colors.white54, size: 42),
      );

  static const _placeholderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2C4A73), Color(0xFF6B87AD)],
  );
}
