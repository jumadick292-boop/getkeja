import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/rental_application_providers.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

/// House seeker application detail with a status timeline, resubmit and
/// withdraw actions, and an onboarding handoff banner.
class RentalApplicationDetailPage extends ConsumerWidget {
  const RentalApplicationDetailPage({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(applicationDetailProvider(applicationId));
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rentalAppTitle)),
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorRetry(
          onRetry: () => ref.invalidate(applicationDetailProvider(applicationId)),
        ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final RentalApplicationDetailModel detail;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: const Text('The landlord will be notified. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(rentalApplicationRepositoryProvider).withdraw(detail.application.id);
      ref.invalidate(applicationDetailProvider(detail.application.id));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not withdraw: $error')),
        );
      }
    }
  }

  Future<void> _resubmit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respond to information request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add your response or note'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );
    if (note == null) return;
    try {
      await ref
          .read(rentalApplicationRepositoryProvider)
          .resubmit(detail.application.id, <String, dynamic>{'responseNote': note});
      ref.invalidate(applicationDetailProvider(detail.application.id));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resubmit: $error')),
        );
      }
    }
  }

  Future<void> _openConversation(BuildContext context, WidgetRef ref) async {
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

  Future<void> _uploadDocument(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty) return;
    final picked = files.first;
    final path = picked.path;
    if (path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file.')),
        );
      }
      return;
    }
    try {
      await ref.read(rentalApplicationRepositoryProvider).uploadDocument(
            detail.application.id,
            path,
            picked.name,
            picked.extension == 'pdf' ? 'application/pdf' : 'image/${picked.extension ?? 'jpeg'}',
            category: 'supporting_document',
          );
      if (context.mounted) {
        ref.invalidate(applicationDetailProvider(detail.application.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload document: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = detail.application;
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (app.propertyTitle != null) ...[
          Text(app.propertyTitle!, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
        ],
        _StatusChip(status: app.status),
        if (app.isOnboarded) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.verified),
                title: Text(l10n.rentalAppOnboarded),
                subtitle: Text(l10n.rentalAppOnboardedDesc),
              ),
            ),
          ),
        ],
        if (app.rejectionReason != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.rentalAppOutcome),
              subtitle: Text(app.rejectionReason!),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (app.proposedRentAmount != null)
          _Row(label: l10n.rentalAppProposedRent, value: 'KES ${app.proposedRentAmount}'),
        if (app.preferredStartDate != null)
          _Row(label: l10n.rentalAppPreferredStart, value: app.preferredStartDate!),
        if (app.preferredEndDate != null)
          _Row(label: l10n.rentalAppPreferredEnd, value: app.preferredEndDate!),
        if (detail.documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.rentalAppDocuments, style: Theme.of(context).textTheme.titleMedium),
          ...detail.documents.map(
            (doc) => ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(doc.fileName ?? ''),
              trailing: doc.verificationStatus == 'verified'
                  ? const Icon(Icons.verified, color: Colors.green)
                  : null,
            ),
          ),
        ],
        if (app.status == 'draft' || app.status == 'information_requested' || app.status == 'pending_documents' || app.canRespondToInfo) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _uploadDocument(context, ref),
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.rentalAppUploadDocument),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.rentalAppTimeline, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...detail.history.map((entry) => _TimelineEntry(entry: entry)),
        const SizedBox(height: 24),
        if (app.canRespondToInfo)
          FilledButton.icon(
            onPressed: () => _resubmit(context, ref),
            icon: const Icon(Icons.reply),
            label: Text(l10n.rentalAppRespond),
          ),
        if (app.canWithdraw) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _withdraw(context, ref),
            child: Text(l10n.rentalAppWithdraw),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openConversation(context, ref),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Message landlord'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(label[0].toUpperCase() + label.substring(1)),
        visualDensity: VisualDensity.compact,
      ),
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
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry});
  final ApplicationHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final status = (entry.newStatus ?? entry.action).replaceAll('_', ' ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.circle, size: 10),
      title: Text(status[0].toUpperCase() + status.substring(1)),
      subtitle: entry.createdAt != null ? Text(entry.createdAt!) : null,
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load this application.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}