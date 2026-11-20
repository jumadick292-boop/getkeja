library features.organizations.presentation.state.organisation_state;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/organizations/data/repositories/organisation_repository_impl.dart';
import 'package:get_keja_mobile/features/organizations/domain/entities/organisation.dart';
import 'package:get_keja_mobile/features/organizations/domain/repositories/organisation_repository.dart';
import 'package:get_keja_mobile/features/organizations/domain/usecases/create_organisation.dart';
import 'package:get_keja_mobile/features/organizations/domain/usecases/get_organisation.dart';
import 'package:get_keja_mobile/features/organizations/domain/usecases/get_organisations.dart';

class OrganisationState {
  const OrganisationState({
    this.organisations = const [],
    this.selectedOrganisation,
    this.isLoading = false,
    this.error,
  });

  final List<Organisation> organisations;
  final Organisation? selectedOrganisation;
  final bool isLoading;
  final String? error;

  OrganisationState copyWith({
    List<Organisation>? organisations,
    Organisation? selectedOrganisation,
    bool? isLoading,
    String? error,
  }) {
    return OrganisationState(
      organisations: organisations ?? this.organisations,
      selectedOrganisation: selectedOrganisation ?? this.selectedOrganisation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class OrganisationNotifier extends Notifier<OrganisationState> {
  @override
  OrganisationState build() => const OrganisationState();

  OrganisationRepository get _repository {
    return ref.read(organisationRepositoryProvider);
  }

  GetOrganisations get _getOrganisations => GetOrganisations(_repository);
  GetOrganisation get _getOrganisation => GetOrganisation(_repository);
  CreateOrganisation get _createOrganisation => CreateOrganisation(_repository);

  Future<void> loadOrganisations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final organisations = await _getOrganisations();
      state = state.copyWith(
        organisations: organisations,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> loadOrganisation(String organisationId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final organisation = await _getOrganisation(organisationId);
      state = state.copyWith(
        selectedOrganisation: organisation,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<bool> createOrganisation({
    required String name,
    required String slug,
    String? type,
    String? description,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String? city,
    String? county,
    String? country,
    String? registrationNumber,
    String? taxId,
    String? logoUrl,
    String? websiteUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final organisation = await _createOrganisation(
        name: name,
        slug: slug,
        type: type,
        description: description,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        address: address,
        city: city,
        county: county,
        country: country,
        registrationNumber: registrationNumber,
        taxId: taxId,
        logoUrl: logoUrl,
        websiteUrl: websiteUrl,
      );
      state = state.copyWith(
        organisations: [...state.organisations, organisation],
        selectedOrganisation: organisation,
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final organisationRepositoryProvider = Provider<OrganisationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrganisationRepositoryImpl.fromApiClient(apiClient);
});

final organisationNotifierProvider =
    NotifierProvider<OrganisationNotifier, OrganisationState>(
  OrganisationNotifier.new,
);

final organisationsProvider = Provider<List<Organisation>>((ref) {
  return ref.watch(organisationNotifierProvider).organisations;
});

final organisationLoadingProvider = Provider<bool>((ref) {
  return ref.watch(organisationNotifierProvider).isLoading;
});

final organisationErrorProvider = Provider<String?>((ref) {
  return ref.watch(organisationNotifierProvider).error;
});
