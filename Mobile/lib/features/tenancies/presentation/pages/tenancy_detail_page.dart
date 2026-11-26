// Tenancy detail page.
// Shows full details of a single tenancy including property and unit info.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';
import 'package:get_keja_mobile/features/tenancies/domain/repositories/tenancy_repository.dart';
import 'package:get_keja_mobile/features/tenancies/presentation/state/tenancy_state.dart';

class TenancyDetailPage extends ConsumerWidget {
  final String tenancyId;

  const TenancyDetailPage({super.key, required this.tenancyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(tenancyDetailProvider(tenancyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenancy Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(tenancyDetailProvider(tenancyId)),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          final TenancyDetailResponse? d = detail;
          if (d == null) {
            return const Center(
              child: Text('Tenancy not found.'),
            );
          }

          final t = d.tenancy;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(t.status),
                const SizedBox(height: 16),
                _buildDetailRow('Tenancy Type', t.tenancyType),
                _buildDetailRow('Status', t.statusLabel),
                if (t.startDate != null)
                  _buildDetailRow('Start Date', t.startDate!),
                if (t.endDate != null) _buildDetailRow('End Date', t.endDate!),
                if (t.rentAmount != null)
                  _buildDetailRow('Rent Amount', 'KES ${t.rentAmount}'),
                if (t.depositAmount != null)
                  _buildDetailRow('Deposit', 'KES ${t.depositAmount}'),
                if (t.rentDueDay != null)
                  _buildDetailRow('Rent Due Day', '${t.rentDueDay}'),
                if (t.paymentMethod != null)
                  _buildDetailRow('Payment Method', t.paymentMethod!),
                const SizedBox(height: 24),
                const Text(
                  'Property',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Title', d.property.title),
                _buildDetailRow('Type', d.property.propertyType),
                _buildDetailRow('Address', d.property.fullAddress),
                _buildDetailRow('Status', d.property.status),
                if (d.unit != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Unit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Unit Number', d.unit!.unitNumber),
                  _buildDetailRow('Type', d.unit!.unitType),
                  if (d.unit!.bedrooms != null)
                    _buildDetailRow(
                      'Bedrooms', '${d.unit!.bedrooms}',
                    ),
                  if (d.unit!.bathrooms != null)
                    _buildDetailRow(
                      'Bathrooms', '${d.unit!.bathrooms}',
                    ),
                  if (d.unit!.rentAmount != null)
                    _buildDetailRow(
                      'Unit Rent', 'KES ${d.unit!.rentAmount}',
                    ),
                  if (d.unit!.depositAmount != null)
                    _buildDetailRow(
                      'Unit Deposit', 'KES ${d.unit!.depositAmount}',
                    ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (t.termsDocumentUrl != null)
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Tenancy Agreement'),
                    subtitle: const Text('View lease document'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open document signed URL
                    },
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Tenancy Agreement'),
                    subtitle: Text('No agreement document available'),
                  ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.green),
                  title: const Text('View Payments & Invoices'),
                  subtitle: const Text('Manage rent payments and view invoices'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed('/tenant/payments');
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load tenancy details',
                style: TextStyle(fontSize: 18, color: Colors.red[700]),
              ),
              const SizedBox(height: 8),
              Text(
                (error as AppException).message,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'draft':
        color = Colors.grey;
        break;
      case 'terminated':
      case 'expired':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

final tenancyDetailProvider = FutureProvider.family<TenancyDetailResponse?, String>((ref, tenancyId) async {
  final repo = ref.watch(tenancyRepositoryProvider);
  return repo.getTenancyById(tenancyId);
});
