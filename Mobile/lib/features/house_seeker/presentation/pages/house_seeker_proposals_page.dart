import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';
import 'package:go_router/go_router.dart';

class HouseSeekerProposalsPage extends ConsumerWidget {
  const HouseSeekerProposalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(houseSeekerProposalsProvider);
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
                  return _ProposalTile(
                    proposal: proposal,
                    onAccept: proposal.canRespond ? () => _respond(context, ref, proposal, 'accept') : null,
                    onDecline: proposal.canRespond ? () => _respond(context, ref, proposal, 'decline') : null,
                    onCounter: proposal.canRespond ? () => _counter(context, ref, proposal) : null,
                    onMessage: () => _messageLandlord(context, ref, proposal),
                  );
                },
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: 'Could not load your proposals.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(houseSeekerProposalsProvider),
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    RentalProposalModel proposal,
    String action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'accept' ? 'Accept proposal?' : 'Decline proposal?'),
        content: Text(
          action == 'accept'
              ? 'This confirms your interest in the offered terms.'
              : 'The landlord will be notified that you declined.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action == 'accept' ? 'Accept' : 'Decline',
              style: TextStyle(color: action == 'accept' ? AppColors.success : AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(houseSeekerRepositoryProvider).respondToProposal(
            proposalId: proposal.id,
            action: action,
          );
      ref.invalidate(houseSeekerProposalsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${action} the proposal. Please try again.')),
        );
      }
    }
  }

  /// Entry point 2: message the landlord from a proposal to negotiate terms.
  /// Reuses startConversation with the rental proposal context so both parties
  /// share one thread per proposal.
  Future<void> _messageLandlord(
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

  Future<void> _counter(BuildContext context, WidgetRef ref, RentalProposalModel proposal) async {
    final rentController = TextEditingController(
      text: proposal.proposedRentAmount?.toString() ?? '',
    );
    final depositController = TextEditingController(
      text: proposal.proposedDepositAmount?.toString() ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Counter offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppTextField(
              controller: rentController,
              label: 'Proposed rent (KES)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: depositController,
              label: 'Proposed deposit (KES)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
        ],
      ),
    );
    if (result != true) return;
    final rent = num.tryParse(rentController.text.trim());
    final deposit = num.tryParse(depositController.text.trim());
    try {
      await ref.read(houseSeekerRepositoryProvider).respondToProposal(
            proposalId: proposal.id,
            action: 'counter',
            counter: <String, dynamic>{
              if (rent != null) 'rentAmount': rent,
              if (deposit != null) 'depositAmount': deposit,
            },
          );
      ref.invalidate(houseSeekerProposalsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the counter offer. Please try again.')),
        );
      }
    }
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    this.onAccept,
    this.onDecline,
    this.onCounter,
    this.onMessage,
  });

  final RentalProposalModel proposal;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCounter;
  final VoidCallback? onMessage;

  Color get _statusColor {
    switch (proposal.status) {
      case 'accepted':
        return AppColors.success;
      case 'declined':
      case 'expired':
      case 'withdrawn':
        return AppColors.inactive;
      case 'sent':
      case 'under_review':
        return AppColors.pending;
      case 'changes_requested':
        return AppColors.warning;
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
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(label: humanizeEnum(proposal.status), color: _statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (proposal.city != null)
            Text(
              proposal.city!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
            ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (proposal.proposedRentAmount != null)
                _Term(label: 'Rent', value: formatPrice(proposal.proposedRentAmount)),
              if (proposal.proposedDepositAmount != null)
                _Term(label: 'Deposit', value: formatPrice(proposal.proposedDepositAmount)),
              if (proposal.proposedRentDueDay != null)
                _Term(label: 'Due day', value: '${proposal.proposedRentDueDay}'),
            ],
          ),
          if (proposal.specialConditions != null && proposal.specialConditions!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              proposal.specialConditions!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (proposal.expiresAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Expires ${formatDateLabel(proposal.expiresAt)}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
            ),
          ],
          if (onAccept != null || onDecline != null || onCounter != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (onCounter != null)
                  TextButton(onPressed: onCounter, child: const Text('Counter')),
                if (onDecline != null)
                  TextButton(
                    onPressed: onDecline,
                    child: const Text('Decline', style: TextStyle(color: AppColors.error)),
                  ),
                if (onAccept != null)
                  FilledButton(onPressed: onAccept, child: const Text('Accept')),
              ],
            ),
          ],
          if (onMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message landlord'),
              ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600)),
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
              'When a landlord sends you rental terms, you can review them here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}