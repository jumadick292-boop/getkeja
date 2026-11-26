library features.property_management.domain.usecases.reschedule_site_visit;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class RescheduleSiteVisit {
  RescheduleSiteVisit(this._repository);

  final PropertyRepository _repository;

  Future<SiteVisit> call({
    required String visitId,
    String? scheduledAt,
    int? durationMinutes,
    String? hostNotes,
  }) {
    return _repository.rescheduleSiteVisit(
      visitId: visitId,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      hostNotes: hostNotes,
    );
  }
}
