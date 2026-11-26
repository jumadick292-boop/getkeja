library features.house_seeker.presentation.state.house_seeker_state;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/house_seeker/data/datasources/house_seeker_remote_datasource.dart';
import 'package:get_keja_mobile/features/house_seeker/data/repositories/house_seeker_repository_impl.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';

final houseSeekerRemoteDataSourceProvider =
    Provider<HouseSeekerRemoteDataSource>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return HouseSeekerRemoteDataSource(apiClient.dio);
    });

final houseSeekerRepositoryProvider = Provider<HouseSeekerRepository>((ref) {
  return HouseSeekerRepositoryImpl(
    ref.watch(houseSeekerRemoteDataSourceProvider),
  );
});

/// Active search filters, preserved when navigating back from details.
class HouseSeekerFilter {
  const HouseSeekerFilter({
    this.q,
    this.city,
    this.county,
    this.neighbourhood,
    this.propertyType,
    this.rentMin,
    this.rentMax,
    this.bedrooms,
    this.bathrooms,
    this.furnished,
    this.amenities,
    this.sort = 'relevance',
  });

  final String? q;
  final String? city;
  final String? county;
  final String? neighbourhood;
  final String? propertyType;
  final num? rentMin;
  final num? rentMax;
  final int? bedrooms;
  final int? bathrooms;
  final String? furnished;
  final String? amenities;
  final String sort;

  bool get isActive =>
      (q != null && q!.isNotEmpty) ||
      (city != null && city!.isNotEmpty) ||
      (county != null && county!.isNotEmpty) ||
      (neighbourhood != null && neighbourhood!.isNotEmpty) ||
      propertyType != null ||
      rentMin != null ||
      rentMax != null ||
      bedrooms != null ||
      bathrooms != null ||
      furnished != null ||
      (amenities != null && amenities!.isNotEmpty);

  int get activeCount => [
    q != null && q!.isNotEmpty,
    city != null && city!.isNotEmpty,
    propertyType != null,
    rentMin != null || rentMax != null,
    bedrooms != null || bathrooms != null,
    furnished != null,
    amenities != null && amenities!.isNotEmpty,
    neighbourhood != null && neighbourhood!.isNotEmpty,
  ].where((e) => e).length;

  HouseSeekerFilter copyWith({
    String? q,
    String? city,
    String? county,
    String? neighbourhood,
    String? propertyType,
    num? rentMin,
    num? rentMax,
    int? bedrooms,
    int? bathrooms,
    String? furnished,
    String? amenities,
    String? sort,
    bool clear = false,
  }) {
    if (clear) {
      return const HouseSeekerFilter();
    }
    return HouseSeekerFilter(
      q: q ?? this.q,
      city: city ?? this.city,
      county: county ?? this.county,
      neighbourhood: neighbourhood ?? this.neighbourhood,
      propertyType: propertyType ?? this.propertyType,
      rentMin: rentMin ?? this.rentMin,
      rentMax: rentMax ?? this.rentMax,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      furnished: furnished ?? this.furnished,
      amenities: amenities ?? this.amenities,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toCriteria() => <String, dynamic>{
    if (q != null && q!.isNotEmpty) 'q': q,
    if (city != null && city!.isNotEmpty) 'city': city,
    if (county != null && county!.isNotEmpty) 'county': county,
    if (neighbourhood != null && neighbourhood!.isNotEmpty)
      'neighbourhood': neighbourhood,
    if (propertyType != null) 'propertyType': propertyType,
    if (rentMin != null) 'rentMin': rentMin,
    if (rentMax != null) 'rentMax': rentMax,
    if (bedrooms != null) 'bedrooms': bedrooms,
    if (bathrooms != null) 'bathrooms': bathrooms,
    if (furnished != null) 'furnished': furnished,
    if (amenities != null && amenities!.isNotEmpty) 'amenities': amenities,
    'sort': sort,
  };

  factory HouseSeekerFilter.fromCriteria(Map<String, dynamic> criteria) {
    String? str(String key) {
      final v = criteria[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    int? integer(String key) {
      final v = criteria[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    num? numeric(String key) {
      final v = criteria[key];
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    return HouseSeekerFilter(
      q: str('q'),
      city: str('city'),
      county: str('county'),
      neighbourhood: str('neighbourhood'),
      propertyType: str('propertyType'),
      rentMin: numeric('rentMin'),
      rentMax: numeric('rentMax'),
      bedrooms: integer('bedrooms'),
      bathrooms: integer('bathrooms'),
      furnished: str('furnished'),
      amenities: str('amenities'),
      sort: str('sort') ?? 'relevance',
    );
  }
}

/// Holds the current filter and the loaded search results.
class HouseSeekerSearchState {
  const HouseSeekerSearchState({
    this.filter = const HouseSeekerFilter(),
    this.result,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedListingId,
  });

  final HouseSeekerFilter filter;
  final SearchResultModel? result;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedListingId;

  List<ListingCardModel> get items =>
      result?.items ?? const <ListingCardModel>[];
  int get total => result?.total ?? 0;
  bool get hasMore => result?.hasMore ?? false;
  bool get isEmpty => !isLoading && (result == null || result!.items.isEmpty);

  HouseSeekerSearchState copyWith({
    HouseSeekerFilter? filter,
    SearchResultModel? result,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? selectedListingId,
  }) {
    return HouseSeekerSearchState(
      filter: filter ?? this.filter,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      selectedListingId: selectedListingId ?? this.selectedListingId,
    );
  }
}

class HouseSeekerSearchNotifier extends Notifier<HouseSeekerSearchState> {
  @override
  HouseSeekerSearchState build() => const HouseSeekerSearchState();

  HouseSeekerRepository get _repo => ref.read(houseSeekerRepositoryProvider);

  Future<void> search({bool append = false, HouseSeekerFilter? filter}) async {
    final activeFilter = filter ?? state.filter;
    if (append && !state.hasMore) return;
    final offset = append ? state.items.length : 0;
    state = state.copyWith(
      filter: activeFilter,
      isLoading: !append,
      isLoadingMore: append,
      error: null,
    );
    try {
      final result = await _repo.searchListings(
        q: activeFilter.q,
        city: activeFilter.city,
        county: activeFilter.county,
        propertyType: activeFilter.propertyType,
        rentMin: activeFilter.rentMin,
        rentMax: activeFilter.rentMax,
        bedrooms: activeFilter.bedrooms,
        bathrooms: activeFilter.bathrooms,
        furnished: activeFilter.furnished,
        amenities: activeFilter.amenities,
        sort: activeFilter.sort,
        limit: 20,
        offset: offset,
      );
      final merged = <ListingCardModel>[
        if (append) ...state.items,
        ...result.items,
      ];
      state = state.copyWith(
        filter: activeFilter,
        result: SearchResultModel(
          items: merged,
          total: result.total,
          limit: result.limit,
          offset: result.offset,
        ),
        isLoading: false,
        isLoadingMore: false,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }

  void applyFilter(HouseSeekerFilter filter) {
    state = state.copyWith(filter: filter);
    search(filter: filter);
  }

  void clearFilter() {
    state = state.copyWith(filter: const HouseSeekerFilter());
    search(filter: const HouseSeekerFilter());
  }

  void selectListing(String? listingId) {
    state = state.copyWith(selectedListingId: listingId);
  }
}

final houseSeekerSearchProvider =
    NotifierProvider<HouseSeekerSearchNotifier, HouseSeekerSearchState>(
      HouseSeekerSearchNotifier.new,
    );

final houseSeekerFeaturedProvider = FutureProvider<List<ListingCardModel>>((
  ref,
) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  return repo.getFeatured();
});

final houseSeekerFacetsProvider = FutureProvider<FilterFacetsModel>((
  ref,
) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  return repo.getFilterFacets();
});

final houseSeekerListingDetailProvider =
    FutureProvider.family<ListingDetailModel, String>((ref, listingId) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getListingDetail(listingId);
    });

final houseSeekerRelatedListingsProvider =
    FutureProvider.family<List<ListingCardModel>, String>((
      ref,
      listingId,
    ) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getRelatedListings(listingId);
    });

final houseSeekerSavedListingsProvider =
    FutureProvider<List<SavedListingModel>>((ref) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getSavedListings();
    });

final houseSeekerSavedSearchesProvider = FutureProvider<List<SavedSearchModel>>(
  (ref) async {
    final repo = ref.watch(houseSeekerRepositoryProvider);
    return repo.getSavedSearches();
  },
);

final houseSeekerEnquiriesProvider = FutureProvider<List<EnquiryModel>>((
  ref,
) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  return repo.getEnquiries();
});

final houseSeekerPreferencesProvider =
    FutureProvider<HouseSeekerPreferencesModel?>((ref) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getPreferences();
    });

/// Tracks which listing ids the current user has saved, for quick toggle UI.
final houseSeekerSavedIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  final saved = await repo.getSavedListings();
  return saved.map((s) => s.listingId).toSet();
});

/// Optimistic save/unsave toggle for a single listing.
///
/// Maintains a local set of saved ids, applies optimistic updates, and
/// rolls back on failure. Invalidates [houseSeekerSavedIdsProvider] on success.
class HouseSeekerToggleSaveNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  HouseSeekerRepository get _repo => ref.read(houseSeekerRepositoryProvider);

  bool isSaved(String listingId) => state.contains(listingId);

  Future<void> toggle(String listingId) async {
    final wasSaved = state.contains(listingId);
    final next = Set<String>.from(state);
    if (wasSaved) {
      next.remove(listingId);
    } else {
      next.add(listingId);
    }
    state = next;
    try {
      if (wasSaved) {
        await _repo.removeSavedListing(listingId);
      } else {
        await _repo.saveListing(listingId);
      }
      ref.invalidate(houseSeekerSavedIdsProvider);
    } catch (error) {
      final rollback = Set<String>.from(state);
      if (wasSaved) {
        rollback.add(listingId);
      } else {
        rollback.remove(listingId);
      }
      state = rollback;
      rethrow;
    }
  }
}

final houseSeekerToggleSaveProvider =
    NotifierProvider<HouseSeekerToggleSaveNotifier, Set<String>>(
      HouseSeekerToggleSaveNotifier.new,
    );

// ---------------------------------------------------------------------------
// Saved searches state management
// ---------------------------------------------------------------------------

class HouseSeekerSavedSearchesNotifier
    extends Notifier<List<SavedSearchModel>> {
  HouseSeekerRepository get _repo => ref.read(houseSeekerRepositoryProvider);

  @override
  List<SavedSearchModel> build() => const [];

  Future<void> load() async {
    state = await _repo.getSavedSearches();
  }

  Future<SavedSearchModel> create({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = true,
    String? alertFrequency,
  }) async {
    final created = await _repo.createSavedSearch(
      name: name,
      criteria: criteria,
      alertsEnabled: alertsEnabled,
      alertFrequency: alertFrequency,
    );
    state = [...state, created];
    return created;
  }

  Future<void> remove(String searchId) async {
    await _repo.deleteSavedSearch(searchId);
    state = state.where((s) => s.id != searchId).toList();
  }

  Future<SavedSearchModel> update({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  }) async {
    final updated = await _repo.updateSavedSearch(
      searchId: searchId,
      name: name,
      criteria: criteria,
      alertsEnabled: alertsEnabled,
      alertFrequency: alertFrequency,
    );
    state = state.map((s) => s.id == searchId ? updated : s).toList();
    return updated;
  }

  Future<SavedSearchModel> run(String searchId) async {
    final result = await _repo.runSavedSearch(searchId);
    state = state.map((s) => s.id == searchId ? result : s).toList();
    return result;
  }
}

final houseSeekerSavedSearchesNotifierProvider =
    NotifierProvider<HouseSeekerSavedSearchesNotifier, List<SavedSearchModel>>(
      HouseSeekerSavedSearchesNotifier.new,
    );

// ---------------------------------------------------------------------------
// Engagement providers
// ---------------------------------------------------------------------------

final houseSeekerSiteVisitsProvider = FutureProvider<List<SiteVisitModel>>((
  ref,
) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  return repo.getSiteVisits();
});

final houseSeekerConversationsProvider =
    FutureProvider<List<ConversationModel>>((ref) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getConversations();
    });

final houseSeekerMessagesProvider =
    FutureProvider.family<List<MessageModel>, String>((
      ref,
      conversationId,
    ) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getMessages(conversationId);
    });

final houseSeekerApplicationsProvider =
    FutureProvider<List<RentalApplicationModel>>((ref) async {
      final repo = ref.watch(houseSeekerRepositoryProvider);
      return repo.getApplications();
    });

final houseSeekerProposalsProvider = FutureProvider<List<RentalProposalModel>>((
  ref,
) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  return repo.getProposals();
});

final houseSeekerJourneyProvider = FutureProvider<RentalJourneyModel>((
  ref,
) async {
  final repo = ref.watch(houseSeekerRepositoryProvider);
  return repo.getJourney();
});

// ---------------------------------------------------------------------------
// Property comparison state
// ---------------------------------------------------------------------------

const int kMaxComparisonItems = 4;

class ComparisonState {
  const ComparisonState({
    this.items = const <ComparisonListingModel>[],
    this.isLoading = false,
    this.error,
  });

  final List<ComparisonListingModel> items;
  final bool isLoading;
  final String? error;

  int get count => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isAtMax => count >= kMaxComparisonItems;
  Set<String> get listingIds => items.map((i) => i.listingId).toSet();

  bool contains(String listingId) => listingIds.contains(listingId);

  ComparisonState copyWith({
    List<ComparisonListingModel>? items,
    bool? isLoading,
    String? error,
  }) {
    return ComparisonState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ComparisonNotifier extends Notifier<ComparisonState> {
  HouseSeekerRepository get _repo => ref.read(houseSeekerRepositoryProvider);

  @override
  ComparisonState build() {
    Future.microtask(() => load());
    return const ComparisonState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getComparison();
      state = state.copyWith(items: result.items, isLoading: false);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> add(String listingId) async {
    if (state.contains(listingId)) return false;
    if (state.isAtMax) return false;

    final wasLoading = state.isLoading;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.addToComparison(listingId);
      if (result.added) {
        // Reload to get full listing details from server.
        await load();
        return true;
      }
      state = state.copyWith(isLoading: wasLoading);
      return false;
    } on AppException catch (error) {
      state = state.copyWith(isLoading: wasLoading, error: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(isLoading: wasLoading, error: error.toString());
      return false;
    }
  }

  Future<bool> remove(String listingId) async {
    if (!state.contains(listingId)) return false;

    final wasLoading = state.isLoading;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.removeFromComparison(listingId);
      if (result.removed) {
        state = state.copyWith(
          items: state.items.where((i) => i.listingId != listingId).toList(),
          isLoading: false,
        );
        return true;
      }
      state = state.copyWith(isLoading: wasLoading);
      return false;
    } on AppException catch (error) {
      state = state.copyWith(isLoading: wasLoading, error: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(isLoading: wasLoading, error: error.toString());
      return false;
    }
  }

  Future<void> clear() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.clearComparison();
      state = const ComparisonState();
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

final houseSeekerComparisonProvider =
    NotifierProvider<ComparisonNotifier, ComparisonState>(
      ComparisonNotifier.new,
    );

/// Quick read of which listing IDs are currently in comparison.
final houseSeekerComparisonIdsProvider = Provider<Set<String>>((ref) {
  final state = ref.watch(houseSeekerComparisonProvider);
  return state.listingIds;
});

/// Number of items in comparison.
final houseSeekerComparisonCountProvider = Provider<int>((ref) {
  final state = ref.watch(houseSeekerComparisonProvider);
  return state.count;
});

/// Whether comparison is at maximum capacity.
final houseSeekerComparisonIsAtMaxProvider = Provider<bool>((ref) {
  final state = ref.watch(houseSeekerComparisonProvider);
  return state.isAtMax;
});
