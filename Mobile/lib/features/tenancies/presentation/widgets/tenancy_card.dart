// Tenancy card widget.
// Displays a summary of a tenancy record in a list.
import 'package:flutter/material.dart';
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';

class TenancyCard extends StatelessWidget {
  final TenancyModel tenancy;
  final VoidCallback onTap;

  const TenancyCard({
    super.key,
    required this.tenancy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tenancy.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(tenancy.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tenancy Type: ${tenancy.tenancyType}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              if (tenancy.startDate != null)
                Text(
                  'Start: ${tenancy.startDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              if (tenancy.endDate != null)
                Text(
                  'End: ${tenancy.endDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              if (tenancy.rentAmount != null)
                Text(
                  'Rent: KES ${tenancy.rentAmount}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (tenancy.depositAmount != null)
                Text(
                  'Deposit: KES ${tenancy.depositAmount}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'draft':
        return Colors.grey;
      case 'terminated':
      case 'expired':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
