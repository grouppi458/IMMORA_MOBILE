import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';
import 'package:immora_mobile/module_gestion_biens/repositories/property_repository.dart';

/// État du Module 5 côté agence / agent : les annonces de l'agence connectée
/// et leurs actions (BF5.1, BF5.3 à BF5.5).
class ListingProvider extends ChangeNotifier {
  ListingProvider({ListingRepository? listings, PropertyRepository? properties})
      : _listings = listings ?? ListingRepository(),
        _properties = properties ?? PropertyRepository();

  final ListingRepository _listings;
  final PropertyRepository _properties;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? errorField; // 'title', 'text', 'price', 'duration', 'property'
  int? agencyId;
  List<ListingDetails> listings = [];

  int count(ListingStatus status) => listings.where((l) => l.listing.status == status).length;

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    errorField = null;
    notifyListeners();
  }

  Future<void> load(int agencyId) async {
    this.agencyId = agencyId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      listings = await _listings.agencyListings(agencyId);
    } catch (e) {
      debugPrint('ListingProvider.load: $e');
      errorMessage = 'Impossible de charger les annonces.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// BF5.1 — biens de l'agence qui peuvent recevoir une annonce.
  Future<List<Property>> availableProperties(int agencyId) =>
      _properties.availableWithoutListing(agencyId);

  Future<bool> create({
    required int propertyId,
    required int agencyId,
    int? createdBy,
    required String title,
    required String text,
    required double displayedPrice,
    required int durationDays,
    required bool isFeatured,
    required bool publish,
  }) =>
      _save(() => _listings.create(
            propertyId: propertyId,
            agencyId: agencyId,
            createdBy: createdBy,
            title: title,
            text: text,
            displayedPrice: displayedPrice,
            durationDays: durationDays,
            isFeatured: isFeatured,
            publish: publish,
          ));

  Future<bool> updateContent(int id,
          {required String title,
          required String text,
          required double displayedPrice,
          required bool isFeatured}) =>
      _save(() async {
        await _listings.updateContent(id,
            title: title, text: text, displayedPrice: displayedPrice);
        await _listings.setFeatured(id, isFeatured);
      });

  Future<bool> publish(int id) => _save(() => _listings.publish(id));
  Future<bool> suspend(int id) => _save(() => _listings.suspend(id));
  Future<bool> extend(int id, int days) => _save(() => _listings.extend(id, days));
  Future<bool> setFeatured(int id, bool featured) =>
      _save(() => _listings.setFeatured(id, featured));
  Future<bool> delete(int id) => _save(() => _listings.delete(id));

  /// Exécute une action, recharge la liste, et garde l'erreur métier à afficher.
  Future<bool> _save(Future<void> Function() action) async {
    isSaving = true;
    errorMessage = null;
    errorField = null;
    notifyListeners();
    try {
      await action();
      if (agencyId != null) listings = await _listings.agencyListings(agencyId!);
      return true;
    } on AdminException catch (e) {
      errorMessage = e.message;
      errorField = e.field;
      return false;
    } catch (e) {
      debugPrint('ListingProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
