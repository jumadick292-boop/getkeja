import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';

/// Repository for the rental application workflow.
///
/// Applicant + manager share this interface; authorization is enforced by the
/// backend. UI should call these and render backend-driven state only.
abstract class RentalApplicationRepository {
  // Applicant
  Future<RentalApplicationRecord> saveDraft(Map<String, dynamic> body);
  Future<RentalApplicationRecord> submitApplication(Map<String, dynamic> body);
  Future<RentalApplicationRecord> submitDraft(String applicationId);
  Future<RentalApplicationRecord> resubmit(
    String applicationId,
    Map<String, dynamic> body,
  );
  Future<RentalApplicationRecord> withdraw(String applicationId);
  Future<RentalApplicationDetailModel> getDetail(String applicationId);

  // Manager
  Future<ManagedApplicationListModel> listInbox({
    String? status,
    String? propertyId,
    int limit,
    int offset,
  });
  Future<RentalApplicationDetailModel> getManagedDetail(String applicationId);
  Future<RentalApplicationRecord> transition(
    String applicationId,
    String action, {
    String? reason,
  });
  Future<({RentalApplicationRecord application, OnboardingResultModel? onboarding})>
      approve(String applicationId, Map<String, dynamic> body);
  Future<OnboardingResultModel> onboard(String applicationId);
  Future<void> addNote(String applicationId, String note);

  // Documents
  Future<ApplicationDocumentModel> uploadDocument(
    String applicationId,
    String filePath,
    String fileName,
    String mimeType, {
    String? category,
  });
  Future<List<ApplicationDocumentModel>> listDocuments(String applicationId);
  Future<String> downloadDocumentUrl(String documentId);
}