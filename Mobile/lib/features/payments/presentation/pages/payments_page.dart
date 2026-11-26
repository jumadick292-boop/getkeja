// Payments page.
// Main entry point for tenant payments: dashboard, invoices, payment methods,
// receipts, statements, deposits.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/financial_dashboard_page.dart';

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const FinancialDashboardPage();
  }
}
