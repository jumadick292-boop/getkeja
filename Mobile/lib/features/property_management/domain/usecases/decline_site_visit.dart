library features.property_management.domain.usecases.decline_site_visit;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class DeclineSiteVisit {
  DeclineSiteVisit(this._repository);

  final PropertyRepository _repository;

  Future<SiteVisit> call({required String visitId, String? reason}) {
    return _repository.declineSiteVisit(visitId: visitId, reason: reason);
  }
}
