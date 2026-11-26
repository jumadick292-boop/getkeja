library features.property_management.domain.usecases.get_site_visits;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetSiteVisits {
  GetSiteVisits(this._repository);

  final PropertyRepository _repository;

  Future<List<SiteVisit>> call({
    String? propertyId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.getSiteVisits(
      propertyId: propertyId,
      status: status,
      limit: limit,
      offset: offset,
    );
  }
}
