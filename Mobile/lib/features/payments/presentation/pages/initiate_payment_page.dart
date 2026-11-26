// Initiate payment page.
// Allows tenant to initiate an M-Pesa STK Push payment for an invoice.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';

class InitiatePaymentPage extends ConsumerStatefulWidget {
  const InitiatePaymentPage({super.key});

  @override
  ConsumerState<InitiatePaymentPage> createState() =>
      _InitiatePaymentPageState();
}

class _InitiatePaymentPageState extends ConsumerState<InitiatePaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController(text: '07');
  bool _isLoading = false;

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .initiateMpesaPayment(
        invoiceId: _invoiceIdController.text.trim(),
        amount: num.tryParse(_amountController.text) ?? 0,
        phoneNumber: _phoneController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data.message),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initiate Payment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'M-Pesa STK Push',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete the payment on your phone after initiating.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _invoiceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Invoice ID is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (KES)',
                        border: OutlineInputBorder(),
                        prefixText: 'KES ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Amount is required';
                        }
                        if (num.tryParse(value) == null ||
                            num.tryParse(value)! <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        hintText: '07XXXXXXXX',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _initiatePayment,
                      icon: const Icon(Icons.phone_android),
                      label: const Text('Initiate STK Push'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
