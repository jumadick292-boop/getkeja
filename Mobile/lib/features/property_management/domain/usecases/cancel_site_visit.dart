library features.property_management.domain.usecases.cancel_site_visit;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class CancelSiteVisit {
  CancelSiteVisit(this._repository);

  final PropertyRepository _repository;

  Future<SiteVisit> call({required String visitId, String? reason}) {
    return _repository.cancelSiteVisit(visitId: visitId, reason: reason);
  }
}
