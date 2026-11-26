import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/rental_application_providers.dart';
import 'package:go_router/go_router.dart';

/// Landlord / manager application review: applicant info, internal notes,
/// information requests, shortlist/reject and final approval + onboarding.
class RentalApplicationReviewPage extends ConsumerWidget {
  const RentalApplicationReviewPage({super.key, required this.applicationId});

  final String applicationId;

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    String? reason,
    Map<String, dynamic>? approveBody,
    String successMessage = 'Updated',
  }) async {
    final repo = ref.read(rentalApplicationRepositoryProvider);
    try {
      if (approveBody != null) {
        await repo.approve(applicationId, approveBody);
      } else {
        await repo.transition(applicationId, action, reason: reason);
      }
      ref.invalidate(applicationDetailProvider(applicationId));
      ref.invalidate(managedInboxProvider(null));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
        );
      }
    }
  }

  Future<void> _requestInformation(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request information'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Tell the applicant what you need'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    await _runAction(context, ref, action: 'request_information', reason: note);
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final rentController = TextEditingController();
    final depositController = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & onboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Approved monthly rent (KES)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: depositController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Approved deposit (KES)'),
            ),
            const SizedBox(height: 8),
            const Text('Approving creates the tenancy and tenant record.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Approve')),
        ],
      ),
    );
    if (approved != true) return;
    final rent = num.tryParse(rentController.text.trim());
    final deposit = num.tryParse(depositController.text.trim());
    await _runAction(
      context,
      ref,
      action: 'approve',
      approveBody: <String, dynamic>{
        if (rent != null) 'approvedRentAmount': rent,
        if (deposit != null) 'approvedDepositAmount': deposit,
      },
      successMessage: 'Application approved',
    );
  }

  /// Entry point 1: message the applicant from the application review surface.
  /// Reuses the existing startConversation flow with the rental application
  /// context so an existing thread is reused rather than duplicated.
  Future<void> _openConversation(
    BuildContext context,
    WidgetRef ref,
    RentalApplicationDetailModel detail,
  ) async {
    try {
      final result = await ref.read(houseSeekerRepositoryProvider).startConversation(
            propertyId: detail.application.propertyId,
            rentalApplicationId: detail.application.id,
            message: '',
          );
      if (context.mounted) {
        context.go('/house-seeker/conversations/${result.conversation.id}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open conversation: $error')),
        );
      }
    }
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Internal note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Only visible to your team'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    try {
      await ref.read(rentalApplicationRepositoryProvider).addNote(applicationId, note);
      ref.invalidate(applicationDetailProvider(applicationId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save note: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(applicationDetailProvider(applicationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review application')),
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(applicationDetailProvider(applicationId)),
            child: const Text('Retry'),
          ),
        ),
        data: (detail) => _ReviewBody(
          detail: detail,
          onStartReview: () => _runAction(context, ref, action: 'start_review', successMessage: 'Moved to review'),
          onShortlist: () => _runAction(context, ref, action: 'shortlist', successMessage: 'Shortlisted'),
          onRequestInfo: () => _requestInformation(context, ref),
          onReject: () => _runAction(context, ref, action: 'reject', reason: 'Rejected', successMessage: 'Rejected'),
          onApprove: () => _approve(context, ref),
          onAddNote: () => _addNote(context, ref),
          onMessage: () => _openConversation(context, ref, detail),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.detail,
    required this.onStartReview,
    required this.onShortlist,
    required this.onRequestInfo,
    required this.onReject,
    required this.onApprove,
    required this.onAddNote,
    required this.onMessage,
  });

  final RentalApplicationDetailModel detail;
  final VoidCallback onStartReview;
  final VoidCallback onShortlist;
  final VoidCallback onRequestInfo;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final VoidCallback onAddNote;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final app = detail.application;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (app.propertyTitle != null)
          Text(app.propertyTitle!, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Status: ${app.status.replaceAll('_', ' ')}'),
        const Divider(height: 24),
        if (app.applicantName != null) _Row(label: 'Applicant', value: app.applicantName!),
        if (app.applicantEmail != null) _Row(label: 'Email', value: app.applicantEmail!),
        if (app.applicantPhone != null) _Row(label: 'Phone', value: app.applicantPhone!),
        if (app.proposedRentAmount != null)
          _Row(label: 'Proposed rent', value: 'KES ${app.proposedRentAmount}'),
        if (app.preferredStartDate != null)
          _Row(label: 'Preferred start', value: app.preferredStartDate!),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: onRequestInfo, child: const Text('Request info')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: onAddNote, child: const Text('Add note')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: onShortlist, child: const Text('Shortlist')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: onReject, child: const Text('Reject')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onMessage,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Message applicant'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check),
          label: const Text('Approve & onboard'),
        ),
        if (detail.documents.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Applicant documents', style: Theme.of(context).textTheme.titleMedium),
          ...detail.documents.map(
            (doc) => ListTile(
              dense: true,
              leading: const Icon(Icons.description_outlined),
              title: Text(doc.fileName ?? 'Document'),
              subtitle: Text(doc.category ?? ''),
              trailing: Text(doc.verificationStatus ?? 'pending'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Internal notes', style: Theme.of(context).textTheme.titleMedium),
        if (detail.notes.isEmpty)
          const Text('No notes yet.')
        else
          ...detail.notes.map(
            (note) => ListTile(
              dense: true,
              leading: Icon(note.isInternal ? Icons.lock_outline : Icons.chat_bubble_outline),
              title: Text(note.note),
              subtitle: note.createdAt != null ? Text(note.createdAt!) : null,
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}