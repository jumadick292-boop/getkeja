library features.property_management.domain.usecases.get_site_visit;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetSiteVisit {
  GetSiteVisit(this._repository);

  final PropertyRepository _repository;

  Future<SiteVisit?> call(String visitId) {
    return _repository.getSiteVisit(visitId);
  }
}
