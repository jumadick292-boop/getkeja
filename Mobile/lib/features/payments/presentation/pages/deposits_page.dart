// Deposits page.
// Shows tenant security deposits and transaction history.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';

class DepositsPage extends ConsumerWidget {
  const DepositsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositsAsync = ref.watch(depositsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(depositsProvider),
          ),
        ],
      ),
      body: depositsAsync.when(
        data: (result) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (result.deposits.isEmpty)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No deposits',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...result.deposits.map((deposit) => _DepositCard(deposit: deposit)),
              if (result.transactions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...result.transactions.map((tx) => ListTile(
                  leading: Icon(
                    tx.transactionType == 'deposit' ? Icons.add : Icons.remove,
                    color: tx.transactionType == 'deposit' ? Colors.green : Colors.red,
                  ),
                  title: Text(tx.transactionType),
                  subtitle: Text(tx.transactionDate),
                  trailing: Text('${tx.currency} ${tx.amount}'),
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

class _DepositCard extends StatelessWidget {
  const _DepositCard({required this.deposit});

  final DepositModel deposit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Security Deposit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(deposit.status),
                  backgroundColor: deposit.status == 'paid'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Expected Amount', value: '${deposit.currency} ${deposit.expectedAmount}'),
            _InfoRow(label: 'Received Amount', value: '${deposit.currency} ${deposit.receivedAmount}'),
            _InfoRow(label: 'Outstanding', value: '${deposit.currency} ${deposit.outstandingAmount}'),
            if (deposit.depositSchemeReference != null)
              _InfoRow(label: 'Scheme Reference', value: deposit.depositSchemeReference!),
            if (deposit.heldBy != null)
              _InfoRow(label: 'Held By', value: deposit.heldBy!),
            if (deposit.refundDueDate != null)
              _InfoRow(label: 'Refund Due', value: deposit.refundDueDate!),
            if (deposit.isFullyPaid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Deposit fully paid',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
