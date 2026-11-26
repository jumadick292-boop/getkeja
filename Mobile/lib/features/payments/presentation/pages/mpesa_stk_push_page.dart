// M-Pesa STK Push payment page.
// Phone input, Kenyan normalization/validation, amount confirmation,
// payment initiation, pending status, backend status polling,
// success and failure states, safe retry.
// Never asks for or stores the M-Pesa PIN.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/validators/validators.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';

class MpesaStkPushPage extends ConsumerStatefulWidget {
  final String invoiceId;
  final num amount;

  const MpesaStkPushPage({
    super.key,
    required this.invoiceId,
    required this.amount,
  });

  @override
  ConsumerState<MpesaStkPushPage> createState() => _MpesaStkPushPageState();
}

class _MpesaStkPushPageState extends ConsumerState<MpesaStkPushPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _paymentTransactionId;
  String? _checkoutRequestId;
  bool _isInitiating = false;
  bool _isPolling = false;
  String? _error;
  String? _status;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isInitiating = true;
      _error = null;
    });

    try {
      final result = await ref.read(paymentRepositoryProvider).initiatePayment(
        invoiceId: widget.invoiceId,
        amount: widget.amount,
        phoneNumber: _phoneController.text.trim(),
        provider: 'mpesa',
      );

      setState(() {
        _paymentTransactionId = result.data.paymentTransactionId;
        _checkoutRequestId = result.data.providerTransactionId;
        _status = result.data.status;
        _isInitiating = false;
      });

      // Start polling for status
      _startPolling();
    } catch (error) {
      setState(() {
        _isInitiating = false;
        _error = error.toString();
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    setState(() {
      _isPolling = true;
      _error = null;
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final result = await ref
            .read(paymentRepositoryProvider)
            .getPaymentStatus(_paymentTransactionId!);

        final status = result.data.status;
        setState(() {
          _status = status;
        });

        if (status == 'completed' || status == 'failed') {
          _pollTimer?.cancel();
          setState(() {
            _isPolling = false;
          });
        }
      } catch (e) {
        // Polling errors are non-fatal; continue polling.
      }
    });

    // Stop polling after 10 minutes
    Future.delayed(const Duration(minutes: 10), () {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() {
          _isPolling = false;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _paymentTransactionId = null;
      _checkoutRequestId = null;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('M-Pesa STK Push')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_paymentTransactionId == null) ...[
                // Initiation form
                AppCardSection(
                  title: l10n.payInvoice,
                  subtitle: '${l10n.amountLabel}: KES ${widget.amount.toStringAsFixed(2)}',
                  children: [
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phoneController,
                      label: l10n.phoneNumber,
                      hintText: '0712345678 or +254712345678',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: Validators.phone,
                      onSubmitted: (_) => _initiatePayment(),
                      autofillHints: const [AutofillHints.telephoneNumber],
                    ),
                    const SizedBox(height: 16),
                    const AppNotice(
                      message: 'You will receive an STK Push on your phone. Enter your M-Pesa PIN to complete the payment. GetKeja will never ask for your PIN.',
                      type: NoticeType.info,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        onPressed: _isInitiating ? null : _initiatePayment,
                        label: _isInitiating ? l10n.initiating : l10n.payNow,
                        icon: const Icon(Icons.phone_android, size: 20),
                        isLoading: _isInitiating,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AppNotice(
                    message: _error!,
                    type: NoticeType.error,
                    actionLabel: l10n.tryAgain,
                    onAction: _retry,
                  ),
                ],
              ] else ...[
                // Pending/success/failure state
                _buildStatusCard(context, l10n),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppLocalizations l10n) {
    final isPending = _status == 'pending';
    final isCompleted = _status == 'completed';
    final isFailed = _status == 'failed';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.1),
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Icon(
                  isPending
                      ? Icons.pending
                      : isCompleted
                          ? Icons.check_circle
                          : Icons.error,
                  color: _statusColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? l10n.paymentPending
                          : isCompleted
                              ? l10n.paymentCompleted
                              : l10n.paymentFailed,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPending
                          ? l10n.waitingForStkPush
                          : isCompleted
                              ? l10n.paymentConfirmed
                              : l10n.paymentDidNotComplete,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_checkoutRequestId != null) ...[
            _detailRow(l10n.transactionReference, _checkoutRequestId!),
            _detailRow(l10n.amountLabel, 'KES ${widget.amount.toStringAsFixed(2)}'),
          ],
          const SizedBox(height: 16),
          if (isCompleted)
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: l10n.viewReceipt,
                icon: const Icon(Icons.receipt, size: 18),
              ),
            )
          else if (isFailed) ...[
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: _retry,
                label: l10n.retryPayment,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: _isPolling ? null : () {
                  setState(() {
                    _isPolling = true;
                  });
                  _startPolling();
                },
                label: _isPolling ? l10n.checkingStatus : l10n.checkStatus,
                isLoading: _isPolling,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: _retry,
                label: l10n.tryDifferentMethod,
                icon: const Icon(Icons.payment, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    if (_status == 'completed') return Colors.green;
    if (_status == 'failed') return Colors.red;
    return Colors.orange;
  }
}
