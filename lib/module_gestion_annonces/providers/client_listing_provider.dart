import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/favorite_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';

/// État du Module 5 côté client : vitrine des annonces publiées (BF5.3),
/// favoris (BF5.2, BF5.5) et annonces récemment consultées.
class ClientListingProvider extends ChangeNotifier {
  ClientListingProvider({ListingRepository? listings, FavoriteRepository? favorites})
      : _listings = listings ?? ListingRepository(),
        _favorites = favorites ?? FavoriteRepository();

  final ListingRepository _listings;
  final FavoriteRepository _favorites;

  static const _recentMax = 5;

  int? clientId;
  bool isLoading = false;
  String? errorMessage;
  List<ListingDetails> published = [];
  List<ListingDetails> favorites = [];
  Set<int> favoriteIds = {};
  List<int> _recentIds = [];

  bool isFavorite(int listingId) => favoriteIds.contains(listingId);

  /// Annonces consultées récemment et toujours en ligne, la plus récente d'abord.
  List<ListingDetails> get recentlyViewed => [
        for (final id in _recentIds)
          ...published.where((d) => d.listing.id == id),
      ];

  String get _recentKey => 'recent_listings_$clientId';

  Future<void> load(int clientId) async {
    this.clientId = clientId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      published = await _listings.publishedListings();
      await _reloadFavorites();
      _recentIds = await _readRecent();
    } catch (e) {
      debugPrint('ClientListingProvider.load: $e');
      errorMessage = 'Impossible de charger les annonces.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// BF5.3 — ouverture de la fiche : compte une vue, mémorise l'annonce dans
  /// « Récemment consultés » et renvoie la fiche à jour.
  Future<ListingDetails?> open(int listingId) async {
    try {
      final current = await _listings.details(listingId);
      if (current != null && current.listing.status == ListingStatus.published) {
        await _listings.recordView(listingId);
        _recentIds = [listingId, ..._recentIds.where((id) => id != listingId)]
            .take(_recentMax)
            .toList();
        await _writeRecent();
        notifyListeners();
      }
      return current;
    } catch (e) {
      debugPrint('ClientListingProvider.open: $e');
      return null;
    }
  }

  /// BF5.2 / BF5.5 — ajoute ou retire des favoris. Renvoie null si l'action a
  /// réussi, sinon le message à afficher.
  Future<String?> toggleFavorite(int listingId) async {
    final id = clientId;
    if (id == null) return 'Connectez-vous pour enregistrer des favoris.';
    try {
      if (isFavorite(listingId)) {
        await _favorites.remove(id, listingId);
      } else {
        await _favorites.add(id, listingId);
      }
      await _reloadFavorites();
      notifyListeners();
      return null;
    } on AdminException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('ClientListingProvider.toggleFavorite: $e');
      return 'Une erreur est survenue. Réessayez.';
    }
  }

  Future<void> _reloadFavorites() async {
    favorites = await _favorites.clientFavorites(clientId!);
    favoriteIds = favorites.map((d) => d.listing.id!).toSet();
  }

  Future<List<int>> _readRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_recentKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, _recentIds.map((id) => '$id').toList());
    } catch (_) {
      // Historique facultatif : on ignore une erreur de stockage.
    }
  }
}
