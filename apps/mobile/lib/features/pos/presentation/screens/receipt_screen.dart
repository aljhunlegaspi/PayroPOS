import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/transaction_provider.dart';
import '../../../../shared/providers/store_provider.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const ReceiptScreen({super.key, required this.transactionId});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  SaleTransaction? _transaction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    // First try to get from lastTransaction
    final lastTransaction = ref.read(lastTransactionProvider);
    if (lastTransaction != null && lastTransaction.id == widget.transactionId) {
      setState(() {
        _transaction = lastTransaction;
        _isLoading = false;
      });
      return;
    }

    // Otherwise fetch from Firestore
    final transaction = await ref.read(transactionProvider.notifier).getTransaction(widget.transactionId);
    setState(() {
      _transaction = transaction;
      _isLoading = false;
    });
  }

  void _shareReceipt() {
    if (_transaction == null) return;

    final store = ref.read(currentStoreProvider);
    final location = ref.read(currentLocationProvider);

    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════');
    buffer.writeln(store?.name ?? 'PayroPOS');
    if (location != null) {
      buffer.writeln(location.name);
      if (location.address != null) buffer.writeln(location.address);
      if (location.phone != null) buffer.writeln('Tel: ${location.phone}');
    }
    buffer.writeln('═══════════════════════════');
    buffer.writeln('');
    buffer.writeln('Receipt: ${_transaction!.receiptNumber}');
    buffer.writeln('Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(_transaction!.createdAt)}');
    buffer.writeln('Cashier: ${_transaction!.staffName}');
    buffer.writeln('───────────────────────────');
    buffer.writeln('');

    for (final item in _transaction!.items) {
      buffer.writeln('${item.name}');
      buffer.writeln('  ${item.quantity} x ${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)} = ${AppConstants.currencySymbol}${item.subtotal.toStringAsFixed(2)}');
    }

    buffer.writeln('');
    buffer.writeln('───────────────────────────');
    buffer.writeln('Subtotal:    ${AppConstants.currencySymbol}${_transaction!.subtotal.toStringAsFixed(2)}');
    buffer.writeln('Tax (${(_transaction!.taxRate * 100).toStringAsFixed(0)}%):      ${AppConstants.currencySymbol}${_transaction!.tax.toStringAsFixed(2)}');
    buffer.writeln('═══════════════════════════');
    buffer.writeln('TOTAL:       ${AppConstants.currencySymbol}${_transaction!.total.toStringAsFixed(2)}');
    buffer.writeln('═══════════════════════════');
    buffer.writeln('');
    buffer.writeln('Payment: ${_transaction!.paymentMethod.toUpperCase()}');
    buffer.writeln('Received: ${AppConstants.currencySymbol}${_transaction!.amountReceived.toStringAsFixed(2)}');
    buffer.writeln('Change:   ${AppConstants.currencySymbol}${_transaction!.change.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('───────────────────────────');
    buffer.writeln('Thank you for your purchase!');
    buffer.writeln('═══════════════════════════');

    Share.share(buffer.toString(), subject: 'Receipt ${_transaction!.receiptNumber}');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(currentStoreProvider);
    final location = ref.watch(currentLocationProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Receipt'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/home'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReceipt,
              tooltip: 'Share Receipt',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transaction == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        const Text('Transaction not found'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Go Home'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Success Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: AppColors.success, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'Sale Complete!',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Receipt Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              // Store Info
                              Text(
                                store?.name ?? 'PayroPOS',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              if (location != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  location.name,
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                if (location.address != null && location.address!.isNotEmpty)
                                  Text(
                                    location.address!,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                if (location.phone != null && location.phone!.isNotEmpty)
                                  Text(
                                    'Tel: ${location.phone}',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                              ],

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Receipt Info
                              _ReceiptInfoRow(
                                label: 'Receipt #',
                                value: _transaction!.receiptNumber,
                              ),
                              _ReceiptInfoRow(
                                label: 'Date',
                                value: DateFormat('MMM dd, yyyy').format(_transaction!.createdAt),
                              ),
                              _ReceiptInfoRow(
                                label: 'Time',
                                value: DateFormat('hh:mm a').format(_transaction!.createdAt),
                              ),
                              _ReceiptInfoRow(
                                label: 'Cashier',
                                value: _transaction!.staffName,
                              ),

                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Items
                              ...(_transaction!.items.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '${item.quantity} x ${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${AppConstants.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ))),

                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Totals
                              _ReceiptTotalRow(
                                label: 'Subtotal',
                                value: '${AppConstants.currencySymbol}${_transaction!.subtotal.toStringAsFixed(2)}',
                              ),
                              _ReceiptTotalRow(
                                label: 'Tax (${(_transaction!.taxRate * 100).toStringAsFixed(0)}%)',
                                value: '${AppConstants.currencySymbol}${_transaction!.tax.toStringAsFixed(2)}',
                              ),
                              const Divider(),
                              _ReceiptTotalRow(
                                label: 'TOTAL',
                                value: '${AppConstants.currencySymbol}${_transaction!.total.toStringAsFixed(2)}',
                                isBold: true,
                                isPrimary: true,
                              ),

                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Payment Info
                              _ReceiptTotalRow(
                                label: 'Payment',
                                value: _transaction!.paymentMethod.toUpperCase(),
                              ),
                              _ReceiptTotalRow(
                                label: 'Amount Received',
                                value: '${AppConstants.currencySymbol}${_transaction!.amountReceived.toStringAsFixed(2)}',
                              ),
                              _ReceiptTotalRow(
                                label: 'Change',
                                value: '${AppConstants.currencySymbol}${_transaction!.change.toStringAsFixed(2)}',
                                isSuccess: true,
                              ),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),

                              // Thank you message
                              Text(
                                'Thank you for your purchase!',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareReceipt,
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.go('/pos'),
                                icon: const Icon(Icons.add),
                                label: const Text('New Sale'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ReceiptInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ReceiptTotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isPrimary;
  final bool isSuccess;

  const _ReceiptTotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isPrimary = false,
    this.isSuccess = false,
  });

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
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
              color: isPrimary
                  ? AppColors.primary
                  : isSuccess
                      ? AppColors.success
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
