import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/customer_provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/cart_provider.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load credit history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerProvider.notifier).loadCreditHistory(widget.customerId);
    });
  }

  Customer? get _customer {
    try {
      return ref.read(customerProvider).customers.firstWhere(
        (c) => c.id == widget.customerId,
      );
    } catch (_) {
      return null;
    }
  }

  void _showRecordPaymentDialog() {
    final customer = _customer;
    if (customer == null) return;

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance: ${AppConstants.currencySymbol}${customer.creditBalance.toStringAsFixed(2)}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '${AppConstants.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // Quick amount buttons
            Wrap(
              spacing: 8,
              children: [
                if (customer.creditBalance > 0) ...[
                  ActionChip(
                    label: const Text('Full'),
                    onPressed: () {
                      controller.text = customer.creditBalance.toStringAsFixed(2);
                    },
                  ),
                  if (customer.creditBalance >= 100)
                    ActionChip(
                      label: const Text('${AppConstants.currencySymbol}100'),
                      onPressed: () => controller.text = '100',
                    ),
                  if (customer.creditBalance >= 500)
                    ActionChip(
                      label: const Text('${AppConstants.currencySymbol}500'),
                      onPressed: () => controller.text = '500',
                    ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }

              final userData = ref.read(userDataProvider);
              final success = await ref.read(customerProvider.notifier).recordPayment(
                customerId: customer.id,
                amount: amount,
                staffId: userData?['uid'] ?? '',
                staffName: userData?['fullName'] ?? 'Staff',
              );

              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)} recorded'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerProvider);
    final customer = _customer;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const Center(child: Text('Customer not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: customer.hasBalance
                        ? AppColors.warning.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: customer.hasBalance
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contact Info
                  if (customer.phone != null && customer.phone!.isNotEmpty)
                    _buildInfoRow(Icons.phone, customer.phone!),
                  if (customer.email != null && customer.email!.isNotEmpty)
                    _buildInfoRow(Icons.email, customer.email!),
                  if (customer.address != null && customer.address!.isNotEmpty)
                    _buildInfoRow(Icons.location_on, customer.address!),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Balance Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Balance',
                        '${AppConstants.currencySymbol}${customer.creditBalance.toStringAsFixed(2)}',
                        customer.owesStore ? AppColors.warning : AppColors.success,
                      ),
                      _buildStatItem(
                        'Credit Limit',
                        customer.creditLimit > 0
                            ? '${AppConstants.currencySymbol}${customer.creditLimit.toStringAsFixed(2)}'
                            : 'Unlimited',
                        AppColors.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRecordPaymentDialog,
                      icon: const Icon(Icons.payments),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Set customer in cart and navigate to POS
                        ref.read(cartProvider.notifier).setCustomer(
                          customer.id,
                          customer.name,
                        );
                        context.push('/pos');
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('New Sale'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Credit History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Transaction History',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (customerState.creditHistory.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'No transaction history',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: customerState.creditHistory.length,
                itemBuilder: (context, index) {
                  final tx = customerState.creditHistory[index];
                  return _CreditHistoryTile(transaction: tx);
                },
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CreditHistoryTile extends StatelessWidget {
  final CreditTransaction transaction;

  const _CreditHistoryTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isPayment = transaction.type == 'payment';
    final isPositive = transaction.amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPayment
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPayment ? Icons.payments : Icons.receipt,
              color: isPayment ? AppColors.success : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPayment ? 'Payment Received' : 'Credit Sale',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (transaction.notes != null && transaction.notes!.isNotEmpty)
                  Text(
                    transaction.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isPayment ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
