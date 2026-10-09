import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/matching_repository.dart';

enum SearchSort {
  compatibility('Compatibilité'),
  priceAsc('Prix ↑'),
  priceDesc('Prix ↓'),
  recent('Récents'),
  surface('Plus grands');

  const SearchSort(this.label);

  final String label;
}

/// D'où vient le profil utilisé pour « Pour vous » (BF5.8).
enum ProfileSource { criteria, favorites, none }

/// Résultat de recherche : l'annonce et, s'il y a un profil, son score.
class SearchHit {
  const SearchHit(this.details, this.match);

  final ListingDetails details;
  final MatchResult? match;
}

/// Alerte « nouvelle annonce pour vous » prête à afficher (BF5.9).
class ListingAlert {
  const ListingAlert(this.notification, this.details, this.match);

  final AppNotification notification;
  final ListingDetails details;
  final MatchResult? match;
}

/// Fonction avancée du Module 5 côté client : recherche intelligente
/// (BF5.6), score de compatibilité (BF5.7), « Pour vous » (BF5.8) et
/// alertes (BF5.9). S'appuie sur les annonces et favoris du
/// [ClientListingProvider].
class MatchingProvider extends ChangeNotifier {
  MatchingProvider(this._client, {MatchingRepository? repository})
      : _repo = repository ?? MatchingRepository() {
    _client.addListener(_onClientChanged);
    // Créé après le chargement des annonces : on rattrape le client courant.
    _clientId = _client.clientId;
    if (_clientId != null) load();
  }

  final ClientListingProvider _client;
  final MatchingRepository _repo;

  int? _clientId;
  SearchCriteria? savedCriteria;
  Set<int> _visited = {};
  List<AppNotification> notifications = [];
  bool isSaving = false;

  // État de l'écran Recherche
  SearchCriteria filters = SearchCriteria.empty;
  String query = '';
  SearchSort sort = SearchSort.compatibility;
  bool showMap = false;

  @override
  void dispose() {
    _client.removeListener(_onClientChanged);
    super.dispose();
  }

  void _onClientChanged() {
    final id = _client.clientId;
    if (id != null && id != _clientId) {
      _clientId = id;
      filters = SearchCriteria.empty;
      query = '';
      load();
    }
    notifyListeners();
  }

  bool get isLoading => _client.isLoading;

  Future<void> load() async {
    final id = _clientId;
    if (id == null) return;
    try {
      savedCriteria = await _repo.criteria(id);
      _visited = await _repo.visitedPropertyIds(id);
      notifications = await _repo.notifications(id);
    } catch (e) {
      debugPrint('MatchingProvider.load: $e');
    }
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    final id = _clientId;
    if (id == null) return;
    notifications = await _repo.notifications(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Profil

  ProfileSource get profileSource {
    if (savedCriteria != null && !savedCriteria!.isEmpty) return ProfileSource.criteria;
    if (_client.favorites.isNotEmpty) return ProfileSource.favorites;
    return ProfileSource.none;
  }

  /// Critères enregistrés, sinon profil déduit des favoris (BF5.8).
  SearchCriteria? get profile => switch (profileSource) {
        ProfileSource.criteria => savedCriteria,
        ProfileSource.favorites => MatchingEngine.profileFromFavorites(_client.favorites),
        ProfileSource.none => null,
      };

  /// Score d'une annonce avec le profil du client (null sans profil).
  MatchResult? matchFor(ListingDetails d) {
    final p = profile;
    return p == null ? null : MatchingEngine.scoreListing(d, p);
  }

  /// BF5.8 — « Pour vous » : les 10 meilleures annonces non visitées.
  List<ScoredListing> get recommendations {
    final p = profile;
    if (p == null) return const [];
    final candidates =
        _client.published.where((d) => !_visited.contains(d.property.id)).toList();
    return MatchingEngine.rank(candidates, p).take(MatchingEngine.recommendationsCount).toList();
  }

  /// BF5.6 — enregistre les critères (« Mes critères », ou la recherche en cours).
  Future<bool> saveCriteria(SearchCriteria c) async {
    final id = _clientId;
    if (id == null) return false;
    isSaving = true;
    notifyListeners();
    try {
      await _repo.saveCriteria(id, c);
      savedCriteria = c;
      return true;
    } catch (e) {
      debugPrint('MatchingProvider.saveCriteria: $e');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- Recherche

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setFilters(SearchCriteria value) {
    filters = value;
    notifyListeners();
  }

  void setSort(SearchSort value) {
    sort = value;
    notifyListeners();
  }

  void toggleMap(bool value) {
    showMap = value;
    notifyListeners();
  }

  /// Raccourci de l'accueil : une recherche sur un type de bien.
  void searchType(PropertyType? type) {
    filters = filters.copyWith(types: type == null ? const {} : {type});
    notifyListeners();
  }

  /// BF5.6 / BF5.7 — annonces publiées qui correspondent à la recherche libre
  /// et aux filtres (score ≥ 50), triées selon [sort]. Sans filtre, le score
  /// est calculé avec le profil du client.
  List<SearchHit> get results => resultsFor(filters, sort: sort);

  List<SearchHit> resultsFor(SearchCriteria f, {SearchSort sort = SearchSort.compatibility}) {
    final scoring = f.isEmpty ? profile : f;
    final hits = <SearchHit>[];
    for (final d in _client.published) {
      if (!MatchingEngine.matchesQuery(d, query)) continue;
      // Dans la recherche, cocher un type veut dire « seulement ce type » ;
      // pour « Pour vous », le type reste une composante du score (10 %).
      if (f.types.isNotEmpty && !f.types.contains(d.property.type)) continue;
      final match = scoring == null ? null : MatchingEngine.scoreListing(d, scoring);
      if (!f.isEmpty && (match == null || !match.isProposed)) continue;
      // Sans filtre, une annonce hors profil (ex. location pour un acheteur)
      // reste visible mais sans score trompeur de 0 %.
      hits.add(SearchHit(d, match != null && match.excluded ? null : match));
    }
    int byDate(SearchHit a, SearchHit b) =>
        (b.details.listing.publishedAt ?? 0).compareTo(a.details.listing.publishedAt ?? 0);
    hits.sort(switch (sort) {
      SearchSort.compatibility => (a, b) {
          final c = (b.match?.score ?? -1).compareTo(a.match?.score ?? -1);
          return c != 0 ? c : byDate(a, b);
        },
      SearchSort.priceAsc => (a, b) =>
          a.details.listing.displayedPrice.compareTo(b.details.listing.displayedPrice),
      SearchSort.priceDesc => (a, b) =>
          b.details.listing.displayedPrice.compareTo(a.details.listing.displayedPrice),
      SearchSort.recent => byDate,
      SearchSort.surface => (a, b) => b.details.property.surface.compareTo(a.details.property.surface),
    });
    return hits;
  }

  /// « Tunis · Appartement » : résumé de la recherche en cours.
  String get searchLabel {
    final parts = [
      if (query.trim().isNotEmpty) query.trim(),
      if (filters.city.trim().isNotEmpty) filters.city.trim(),
      if (filters.district.trim().isNotEmpty) filters.district.trim(),
      ...filters.types.map((t) => t.label),
      if (filters.budgetMax != null) '< ${formatNumber(filters.budgetMax!)}',
    ];
    return parts.join(' · ');
  }

  /// [noResults] — si élargir le budget de 20 % ou retirer le quartier
  /// donne des résultats, le propose.
  String? get suggestion {
    if (results.isNotEmpty || filters.isEmpty) return null;
    if (filters.budgetMax != null) {
      final wider = (filters.budgetMax! * 1.2 / 1000).round() * 1000.0;
      final n = resultsFor(filters.copyWith(budgetMax: () => wider)).length;
      if (n > 0) {
        return 'Suggestion : budget jusqu’à ${formatNumber(wider)} TND → '
            '$n bien${n > 1 ? 's' : ''} disponible${n > 1 ? 's' : ''}.';
      }
    }
    if (filters.district.trim().isNotEmpty) {
      final n = resultsFor(filters.copyWith(district: '')).length;
      if (n > 0) {
        return 'Suggestion : sans quartier précis → $n bien${n > 1 ? 's' : ''} '
            'dans toute la ville.';
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- Alertes

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// BF5.9 — alertes « nouvelle annonce pour vous » dont l'annonce est en ligne.
  List<ListingAlert> get listingAlerts => [
        for (final n in notifications)
          if (n.type == AppNotification.newListing)
            for (final d in _client.published.where((d) => d.listing.id == n.listingId))
              ListingAlert(n, d, matchFor(d)),
      ];

  /// La plus récente alerte non lue (carte « Nouveau bien pour vous » de l'accueil).
  ListingAlert? get latestUnreadAlert =>
      listingAlerts.where((a) => !a.notification.isRead).firstOrNull;

  Future<void> markRead(AppNotification n) async {
    if (n.isRead || n.id == null) return;
    await _repo.markRead(n.id!);
    await refreshNotifications();
  }

  Future<void> markAllRead() async {
    final id = _clientId;
    if (id == null) return;
    await _repo.markAllRead(id);
    await refreshNotifications();
  }
}
