import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/provider/domain/entities/provider_dashboard.dart';
import 'package:get_keja_mobile/features/provider/domain/repositories/provider_repository.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';
import 'package:get_keja_mobile/features/provider/presentation/pages/provider_services_page.dart';
import 'package:get_keja_mobile/features/provider/presentation/pages/provider_locations_page.dart';
import 'package:get_keja_mobile/features/provider/presentation/pages/provider_availability_page.dart';

class FakeProviderRepository implements ProviderRepository {
  FakeProviderRepository({this.offerings = const [], this.locations = const [], this.catalogue = const {}});

  final List<Map<String, dynamic>> offerings;
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic> catalogue;
  bool created = false;

  @override
  Future<ProviderDashboard> getDashboard({String? organizationId}) async =>
      ProviderDashboard.fromJson(<String, dynamic>{
        'newEligibleRequests': 0,
        'assignedRequests': 0,
        'pendingResponses': 0,
        'acceptedJobs': 0,
        'upcomingJobs': 0,
        'activeJobs': 0,
        'completedJobs': 0,
        'cancelledJobs': 0,
        'pendingQuotations': 0,
      });

  @override
  Future<List<Map<String, dynamic>>> listProfiles() async =>
      <Map<String, dynamic>>[{'id': 'profile-1'}];

  @override
  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> body) async => body;
  @override
  Future<List<Map<String, dynamic>>> listOrganizations() async => [];
  @override
  Future<Map<String, dynamic>> createOrganization(Map<String, dynamic> body) async => body;
  @override
  Future<List<Map<String, dynamic>>> listStaff(String organizationId) async => [];
  @override
  Future<Map<String, dynamic>> inviteStaff(String organizationId, Map<String, dynamic> body) async => body;

  @override
  Future<Map<String, dynamic>> getCatalogue({String? domain}) async => catalogue;

  @override
  Future<List<Map<String, dynamic>>> listOfferings({String? organizationId, String? domain, String? status}) async =>
      offerings;

  @override
  Future<Map<String, dynamic>> createOffering(Map<String, dynamic> body) async {
    created = true;
    return <String, dynamic>{'id': 'svc-1', ...body};
  }

  @override
  Future<Map<String, dynamic>> getOffering(String serviceId) async => <String, dynamic>{'id': serviceId};
  @override
  Future<Map<String, dynamic>> updateOffering(String serviceId, Map<String, dynamic> body) async => body;
  @override
  Future<Map<String, dynamic>> setOfferingStatus(String serviceId, String action, {Map<String, dynamic>? body}) async =>
      <String, dynamic>{'id': serviceId, 'status': action == 'activate' ? 'active' : 'paused'};
  @override
  Future<List<Map<String, dynamic>>> getCapabilities(String serviceId) async => [];
  @override
  Future<List<Map<String, dynamic>>> replaceCapabilities(String serviceId, List<Map<String, dynamic>> caps) async => caps;
  @override
  Future<Map<String, dynamic>?> getPricing(String serviceId) async => null;
  @override
  Future<Map<String, dynamic>> setPricing(String serviceId, Map<String, dynamic> body) async => body;

  @override
  Future<List<Map<String, dynamic>>> listLocations({String? organizationId}) async => locations;
  @override
  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> body) async => <String, dynamic>{'id': 'loc-1', ...body};
  @override
  Future<Map<String, dynamic>> updateLocation(String locationId, Map<String, dynamic> body) async => body;
  @override
  Future<void> deleteLocation(String locationId) async {}
  @override
  Future<Map<String, dynamic>> setPrimaryLocation(String locationId) async => <String, dynamic>{'id': locationId};

  @override
  Future<List<Map<String, dynamic>>> listServiceAreas({String? profileId, String? offeringId}) async => [];
  @override
  Future<Map<String, dynamic>> createServiceArea(Map<String, dynamic> body) async => body;
  @override
  Future<void> deleteServiceArea(String areaId) async {}

  @override
  Future<List<Map<String, dynamic>>> getAvailability({String? profileId, String? offeringId}) async => [];
  @override
  Future<List<Map<String, dynamic>>> putAvailability(Map<String, dynamic> body) async => (body['hours'] as List).cast<Map<String, dynamic>>();
  @override
  Future<List<Map<String, dynamic>>> listExceptions(String profileId, {String? offeringId}) async => [];
  @override
  Future<Map<String, dynamic>> createException(Map<String, dynamic> body) async => body;
  @override
  Future<void> deleteException(String exceptionId) async {}
}

Widget _app(Widget child, ProviderRepository repo) {
  return ProviderScope(
    overrides: [providerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('services overview lists offerings and validates required title', (tester) async {
    final repo = FakeProviderRepository(
      offerings: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'svc-1', 'title': 'Household moves', 'categoryName': 'Household moving', 'status': 'active'},
      ],
      catalogue: <String, dynamic>{
        'categories': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'moving_local', 'domain': 'moving', 'name': 'Local moving'},
        ],
        'capabilities': <Map<String, dynamic>>[],
      },
    );
    await tester.pumpWidget(_app(const ProviderServicesPage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('Household moves'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Submitting with empty title should surface validation.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('locations page shows public/private visibility', (tester) async {
    final repo = FakeProviderRepository(
      locations: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'loc-1', 'city': 'Nairobi', 'locationType': 'business_office', 'isPublic': true, 'isPrimary': true},
        <String, dynamic>{'id': 'loc-2', 'city': 'Home', 'locationType': 'provider_operating', 'isPublic': false, 'isPrimary': false},
      ],
    );
    await tester.pumpWidget(_app(const ProviderLocationsPage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('Nairobi'), findsOneWidget);
    expect(find.textContaining('Public'), findsWidgets);
    expect(find.textContaining('Private'), findsWidgets);
  });

  testWidgets('availability page renders seven day rows', (tester) async {
    final repo = FakeProviderRepository();
    await tester.pumpWidget(_app(const ProviderAvailabilityPage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(7));
  });

  testWidgets('swahili localization renders provider services title', (tester) async {
    final repo = FakeProviderRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          locale: Locale('sw'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderServicesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HUDUMA'), findsOneWidget);
  });
}