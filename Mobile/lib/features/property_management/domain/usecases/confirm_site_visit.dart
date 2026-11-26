library features.property_management.domain.usecases.confirm_site_visit;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class ConfirmSiteVisit {
  ConfirmSiteVisit(this._repository);

  final PropertyRepository _repository;

  Future<SiteVisit> call({required String visitId, String? hostNotes}) {
    return _repository.confirmSiteVisit(visitId: visitId, hostNotes: hostNotes);
  }
}
