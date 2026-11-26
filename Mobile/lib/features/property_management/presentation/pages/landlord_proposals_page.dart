import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';
import 'package:get_keja_mobile/features/property_management/data/datasources/property_remote_datasource.dart';
import 'package:go_router/go_router.dart';

/// Loads the landlord / manager facing rental proposals for review.
final landlordProposalsProvider =
    FutureProvider.autoDispose<List<RentalProposalModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final dataSource = PropertyRemoteDataSource(apiClient.dio);
  return dataSource.getRentalProposals();
});

/// Landlord / manager proposal review surface.
///
/// Entry point 3 of the messaging closure: a manager reviewing a rental
/// proposal can message the prospective renter in the proposal's shared
/// conversation (reusing startConversation), and can send / request changes /
/// accept / decline / withdraw / confirm through the existing proposal action
/// endpoint.
class LandlordProposalsPage extends ConsumerWidget {
  const LandlordProposalsPage({super.key});

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref, {
    required RentalProposalModel proposal,
    required String action,
    String? reason,
    required String successMessage,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final dataSource = PropertyRemoteDataSource(apiClient.dio);
      await dataSource.actionRentalProposal(
        proposalId: proposal.id,
        action: action,
        reason: reason,
      );
      ref.invalidate(landlordProposalsProvider);
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

  Future<void> _messageSeeker(
    BuildContext context,
    WidgetRef ref,
    RentalProposalModel proposal,
  ) async {
    try {
      final result = await ref.read(houseSeekerRepositoryProvider).startConversation(
            propertyId: proposal.propertyId,
            rentalProposalId: proposal.id,
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

  Future<void> _requestChanges(
    BuildContext context,
    WidgetRef ref,
    RentalProposalModel proposal,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request changes'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe the changes you want from the renter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _runAction(
      context,
      ref,
      proposal: proposal,
      action: 'request_changes',
      reason: reason,
      successMessage: 'Changes requested',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(landlordProposalsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Rental proposals')),
      body: proposalsAsync.when(
        data: (proposals) => proposals.isEmpty
            ? const _EmptyProposals()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: proposals.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final proposal = proposals[index];
                  return _ProposalReviewCard(
                    proposal: proposal,
                    onMessage: () => _messageSeeker(context, ref, proposal),
                    onSend: proposal.status == 'draft'
                        ? () => _runAction(
                              context,
                              ref,
                              proposal: proposal,
                              action: 'send',
                              successMessage: 'Proposal sent',
                            )
                        : null,
                    onRequestChanges: _canRespond(proposal)
                        ? () => _requestChanges(context, ref, proposal)
                        : null,
                    onAccept: proposal.status == 'accepted' ||
                            proposal.status == 'confirmed'
                        ? null
                        : () => _runAction(
                              context,
                              ref,
                              proposal: proposal,
                              action: 'confirm',
                              successMessage: 'Proposal confirmed',
                            ),
                    onWithdraw: _canRespond(proposal)
                        ? () => _runAction(
                              context,
                              ref,
                              proposal: proposal,
                              action: 'withdraw',
                              successMessage: 'Proposal withdrawn',
                            )
                        : null,
                  );
                },
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: 'Could not load proposals.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(landlordProposalsProvider),
        ),
      ),
    );
  }

  bool _canRespond(RentalProposalModel proposal) =>
      <String>['sent', 'under_review', 'changes_requested'].contains(
        proposal.status,
      );
}

class _ProposalReviewCard extends StatelessWidget {
  const _ProposalReviewCard({
    required this.proposal,
    required this.onMessage,
    this.onSend,
    this.onRequestChanges,
    this.onAccept,
    this.onWithdraw,
  });

  final RentalProposalModel proposal;
  final VoidCallback onMessage;
  final VoidCallback? onSend;
  final VoidCallback? onRequestChanges;
  final VoidCallback? onAccept;
  final VoidCallback? onWithdraw;

  Color get _statusColor {
    switch (proposal.status) {
      case 'accepted':
      case 'confirmed':
        return AppColors.success;
      case 'declined':
      case 'expired':
      case 'withdrawn':
        return AppColors.inactive;
      case 'changes_requested':
        return AppColors.warning;
      case 'sent':
      case 'under_review':
        return AppColors.pending;
      default:
        return AppColors.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  proposal.displayTitle,
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: AppBorderRadius.roundRadius,
                ),
                child: Text(
                  humanizeEnum(proposal.status),
                  style: AppTypography.labelSmall.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (proposal.proposedRentAmount != null)
                _Term(
                  label: 'Rent',
                  value: formatPrice(proposal.proposedRentAmount),
                ),
              if (proposal.proposedDepositAmount != null)
                _Term(
                  label: 'Deposit',
                  value: formatPrice(proposal.proposedDepositAmount),
                ),
              if (proposal.proposedRentDueDay != null)
                _Term(
                  label: 'Due day',
                  value: '${proposal.proposedRentDueDay}',
                ),
            ],
          ),
          if (proposal.expiresAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Expires ${formatDateLabel(proposal.expiresAt)}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message renter'),
            ),
          ),
          if (onSend != null ||
              onRequestChanges != null ||
              onAccept != null ||
              onWithdraw != null) ...<Widget>[
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: <Widget>[
                if (onSend != null)
                  TextButton(onPressed: onSend, child: const Text('Send')),
                if (onRequestChanges != null)
                  TextButton(
                    onPressed: onRequestChanges,
                    child: const Text('Request changes'),
                  ),
                if (onWithdraw != null)
                  TextButton(
                    onPressed: onWithdraw,
                    child: const Text(
                      'Withdraw',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                if (onAccept != null)
                  FilledButton(
                    onPressed: onAccept,
                    child: const Text('Confirm'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText)),
        Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyProposals extends StatelessWidget {
  const _EmptyProposals();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.request_quote_outlined, size: 56, color: AppColors.inactive),
            const SizedBox(height: AppSpacing.md),
            Text('No proposals yet', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Proposals you send to prospective renters will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}