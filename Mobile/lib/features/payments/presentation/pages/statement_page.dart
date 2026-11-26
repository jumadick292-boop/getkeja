// Statement page.
// Shows tenant statement with charges, payments, and balances.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';

class StatementPage extends ConsumerWidget {
  const StatementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementAsync = ref.watch(statementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(statementProvider),
          ),
        ],
      ),
      body: statementAsync.when(
        data: (statement) {
          final data = statement.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statement Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(label: 'Period', value: '${data.fromDate} to ${data.toDate}'),
                      _SummaryRow(label: 'Opening Balance', value: '${data.currency} ${data.openingBalance}'),
                      _SummaryRow(label: 'Total Charges', value: '${data.currency} ${data.totalCharges}'),
                      _SummaryRow(label: 'Total Paid', value: '${data.currency} ${data.totalPaid}'),
                      _SummaryRow(
                        label: 'Closing Balance',
                        value: '${data.currency} ${data.closingBalance}',
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (data.charges.isNotEmpty) ...[
                const Text(
                  'Charges',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...data.charges.map((charge) => ListTile(
                  title: Text(charge['invoiceNumber'] ?? 'Invoice'),
                  subtitle: Text(charge['dueDate'] ?? ''),
                  trailing: Text('${data.currency} ${charge['amount']}'),
                )),
              ],
              if (data.payments.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Payments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...data.payments.map((payment) => ListTile(
                  title: Text(payment['reference'] ?? 'Payment'),
                  subtitle: Text(payment['paymentDate'] ?? ''),
                  trailing: Text('${data.currency} ${payment['amount']}'),
                )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? Colors.black : Colors.grey,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? Colors.green : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
