// Receipt list item widget.
// Displays a single receipt in a list with download action.
import 'package:flutter/material.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';

class ReceiptListItem extends StatelessWidget {
  const ReceiptListItem({super.key, required this.receipt});

  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.receipt, color: Colors.green),
        title: Text(
          receipt.receiptNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment: ${receipt.paymentTransactionId}'),
            Text(
              '${receipt.currency} ${receipt.amount}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(receipt.paymentDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Outstanding: ${receipt.currency} ${receipt.outstandingBalanceAfter}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              onPressed: () {
                // Download receipt via signed URL
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
