import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_photo.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_photo_view.dart';

/// BF3.2 — « Photos du bien » [photoPicker] : appareil photo / galerie,
/// 10 photos maximum, appui long pour glisser et réordonner (la première est
/// la principale), suppression photo par photo.
class PropertyPhotosScreen extends StatefulWidget {
  const PropertyPhotosScreen({super.key, required this.propertyId});

  final int propertyId;

  @override
  State<PropertyPhotosScreen> createState() => _PropertyPhotosScreenState();
}

class _PropertyPhotosScreenState extends State<PropertyPhotosScreen> {
  List<PropertyPhoto> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = await context.read<PropertyProvider>().photos(widget.propertyId);
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  /// image_picker → copie dans /photos/ (path_provider), comme les logos d'agence.
  Future<void> _pick(ImageSource source) async {
    if (_photos.length >= propertyPhotoMaxCount) {
      _snack('$propertyPhotoMaxCount photos au maximum par bien.');
      return;
    }
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final dir = Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'photos'));
      await dir.create(recursive: true);
      final target = p.join(dir.path,
          'property_${widget.propertyId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}');
      await File(picked.path).copy(target);
      if (!mounted) return;

      final provider = context.read<PropertyProvider>();
      final ok = await provider.addPhoto(widget.propertyId, target);
      if (!ok) {
        _snack(provider.errorMessage ?? 'Photo non ajoutée.');
        return;
      }
      await _load();
    } catch (e) {
      _snack('Impossible d’ouvrir la galerie.');
    }
  }

  Future<void> _remove(PropertyPhoto photo) async {
    final provider = context.read<PropertyProvider>();
    final ok = await provider.removePhoto(widget.propertyId, photo.id!);
    _snack(ok ? 'Photo supprimée' : provider.errorMessage ?? 'Suppression impossible.');
    await _load();
  }

  /// Glisser-déposer : la photo lâchée prend la place de la photo visée.
  Future<void> _move(int from, int to) async {
    if (from == to) return;
    final provider = context.read<PropertyProvider>();
    final ids = _photos.map((ph) => ph.id!).toList();
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    var ok = await provider.reorderPhotos(widget.propertyId, ids);
    if (ok && to == 0) ok = await provider.setMainPhoto(widget.propertyId, ids.first);
    if (!ok) _snack(provider.errorMessage ?? 'Réorganisation impossible.');
    await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Photos du bien'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                    child: _ImportButton(
                        icon: Icons.photo_camera_outlined,
                        label: 'Appareil photo',
                        onTap: () => _pick(ImageSource.camera)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ImportButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galerie',
                        onTap: () => _pick(ImageSource.gallery)),
                  ),
                ]),
                const SizedBox(height: 14),
                const MessageBanner(
                  type: BannerType.info,
                  message: 'image_picker → copie dans /photos/ (path_provider). '
                      'Appui long puis glissez une photo pour changer l’ordre : la '
                      'première est la principale.',
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Text('${_photos.length} / $propertyPhotoMaxCount photos',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  const Text('Glisser pour réordonner',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ]),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (var i = 0; i < _photos.length; i++) _tile(i),
                    if (_photos.length < propertyPhotoMaxCount) _addTile(),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Terminé'),
          ),
        ),
      ),
    );
  }

  Widget _tile(int index) {
    final photo = _photos[index];
    final tile = _PhotoTile(
      photo: photo,
      isMain: index == 0,
      onRemove: () => _remove(photo),
    );
    return DragTarget<int>(
      onAcceptWithDetails: (details) => _move(details.data, index),
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: index,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: SizedBox(width: 160, height: 160, child: tile),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        child: tile,
      ),
    );
  }

  Widget _addTile() => InkWell(
        onTap: () => _pick(ImageSource.gallery),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add, color: AppColors.textMuted, size: 28),
            SizedBox(height: 4),
            Text('Ajouter', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
      );
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.isMain, required this.onRemove});

  final PropertyPhoto photo;
  final bool isMain;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(fit: StackFit.expand, children: [
        PropertyPhotoView(photo.path),
        if (isMain)
          const Positioned(
            left: 8,
            top: 8,
            child: StatusBadge('Principale', toneGold),
          ),
        Positioned(
          right: 6,
          top: 6,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline, size: 18, color: AppColors.primary),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
