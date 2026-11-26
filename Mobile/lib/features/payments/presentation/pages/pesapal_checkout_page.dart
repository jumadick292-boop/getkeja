// Pesapal hosted checkout page.
// Initiates checkout, launches the hosted checkout URL, handles return,
// refreshes backend payment status, and shows pending/success/failure/cancellation states.
// A browser redirect is never treated as proof of successful payment.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PesapalCheckoutPage extends ConsumerStatefulWidget {
  final String invoiceId;
  final num amount;

  const PesapalCheckoutPage({
    super.key,
    required this.invoiceId,
    required this.amount,
  });

  @override
  ConsumerState<PesapalCheckoutPage> createState() => _PesapalCheckoutPageState();
}

class _PesapalCheckoutPageState extends ConsumerState<PesapalCheckoutPage> {
  String? _checkoutUrl;
  String? _paymentTransactionId;
  bool _isInitiating = false;
  String? _error;
  String? _status;
  bool _isPolling = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiateCheckout() async {
    setState(() {
      _isInitiating = true;
      _error = null;
    });

    try {
      final result = await ref.read(paymentRepositoryProvider).initiatePayment(
        invoiceId: widget.invoiceId,
        amount: widget.amount,
        provider: 'pesapal',
      );

      setState(() {
        _paymentTransactionId = result.data.paymentTransactionId;
        _checkoutUrl = result.data.checkoutUrl;
        _status = result.data.status;
        _isInitiating = false;
      });

      if (_checkoutUrl != null) {
        await _launchCheckout(_checkoutUrl!);
      }

      _startPolling();
    } catch (error) {
      setState(() {
        _isInitiating = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _launchCheckout(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() {
        _error = 'Could not launch checkout URL';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    setState(() {
      _isPolling = true;
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_paymentTransactionId == null) return;
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
        // Polling errors are non-fatal.
      }
    });

    Future.delayed(const Duration(minutes: 10), () {
      _pollTimer?.cancel();
      if (mounted) setState(() => _isPolling = false);
    });
  }

  void _refreshStatus() async {
    if (_paymentTransactionId == null) return;
    setState(() => _isPolling = true);
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .getPaymentStatus(_paymentTransactionId!);
      setState(() {
        _status = result.data.status;
        _isPolling = false;
      });
    } catch (e) {
      setState(() => _isPolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Pesapal Checkout')),
      body: _isInitiating
          ? const Center(child: CircularProgressIndicator())
          : _checkoutUrl == null
              ? _buildErrorState(context, l10n)
              : _buildStatusState(context, l10n),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? l10n.checkoutFailed,
            style: const TextStyle(fontSize: 18, color: Colors.red),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            onPressed: _initiateCheckout,
            label: l10n.retryAction,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusState(BuildContext context, AppLocalizations l10n) {
    final isPending = _status == 'pending';
    final isCompleted = _status == 'completed';
    final isFailed = _status == 'failed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
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
                                ? l10n.completePaymentInBrowser
                                : isCompleted
                                    ? l10n.paymentConfirmedByProvider
                                    : l10n.paymentNotConfirmed,
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
                if (_paymentTransactionId != null)
                  _detailRow(l10n.transactionReference, _paymentTransactionId!),
                _detailRow(l10n.amountLabel, 'KES ${widget.amount.toStringAsFixed(2)}'),
                if (_checkoutUrl != null)
                  _detailRow(
                    l10n.checkoutUrl,
                    _checkoutUrl!,
                    copyable: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                onPressed: _initiateCheckout,
                label: l10n.retryPayment,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: _isPolling ? null : _refreshStatus,
                label: _isPolling ? l10n.checkingStatus : l10n.checkStatus,
                isLoading: _isPolling,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: () => Navigator.of(context).pop(),
                label: l10n.chooseDifferentMethod,
                icon: const Icon(Icons.payment, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              tooltip: 'Copy',
            ),
          ],
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
