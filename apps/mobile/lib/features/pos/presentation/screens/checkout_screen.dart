import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/cart_provider.dart';
import '../../../../shared/providers/transaction_provider.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/providers/customer_provider.dart';

enum PaymentMethod { cash, gcash, maya, card, credit }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _amountInput = '';
  bool _isProcessing = false;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  final _referenceController = TextEditingController();
  Customer? _selectedCustomer;

  double get _amountReceived {
    if (_amountInput.isEmpty) return 0;
    return double.tryParse(_amountInput) ?? 0;
  }

  double get _change {
    final cart = ref.read(cartProvider);
    return _amountReceived - cart.total;
  }

  bool get _canComplete {
    final cart = ref.read(cartProvider);

    switch (_selectedPaymentMethod) {
      case PaymentMethod.cash:
        return _amountReceived >= cart.total && !_isProcessing;
      case PaymentMethod.gcash:
      case PaymentMethod.maya:
        // Must have reference number
        return _referenceController.text.trim().isNotEmpty && !_isProcessing;
      case PaymentMethod.card:
        return !_isProcessing;
      case PaymentMethod.credit:
        // Must have a customer selected
        return _selectedCustomer != null && !_isProcessing;
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      // Handle decimal point
      if (digit == '.') {
        if (_amountInput.contains('.')) return;
        if (_amountInput.isEmpty) {
          _amountInput = '0.';
        } else {
          _amountInput += '.';
        }
      } else {
        // Limit decimal places to 2
        if (_amountInput.contains('.')) {
          final parts = _amountInput.split('.');
          if (parts[1].length >= 2) return;
        }
        _amountInput += digit;
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_amountInput.isNotEmpty) {
      setState(() {
        _amountInput = _amountInput.substring(0, _amountInput.length - 1);
      });
    }
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _amountInput = '';
    });
  }

  void _setExactAmount() {
    final cart = ref.read(cartProvider);
    setState(() {
      _amountInput = cart.total.toStringAsFixed(2);
    });
  }

  void _setQuickAmount(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _amountInput = amount.toStringAsFixed(2);
    });
  }

  void _selectCustomer() async {
    final customers = ref.read(customerProvider).customers;

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customers found. Add a customer first.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerSelector(customers: customers),
    );

    if (selected != null) {
      setState(() => _selectedCustomer = selected);
    }
  }

  Future<void> _completeTransaction() async {
    if (!_canComplete) return;

    setState(() => _isProcessing = true);

    try {
      final cart = ref.read(cartProvider);
      String paymentMethod;
      double amountReceived;

      switch (_selectedPaymentMethod) {
        case PaymentMethod.cash:
          paymentMethod = 'cash';
          amountReceived = _amountReceived;
          break;
        case PaymentMethod.gcash:
          paymentMethod = 'gcash';
          amountReceived = cart.total;
          break;
        case PaymentMethod.maya:
          paymentMethod = 'maya';
          amountReceived = cart.total;
          break;
        case PaymentMethod.card:
          paymentMethod = 'card';
          amountReceived = cart.total;
          break;
        case PaymentMethod.credit:
          paymentMethod = 'credit';
          amountReceived = 0; // No payment received yet
          break;
      }

      final transaction = await ref.read(transactionProvider.notifier).completeTransaction(
        cart: cart,
        amountReceived: amountReceived,
        paymentMethod: paymentMethod,
      );

      // If credit sale, add to customer's balance
      if (_selectedPaymentMethod == PaymentMethod.credit && _selectedCustomer != null) {
        await ref.read(customerProvider.notifier).addCredit(
          customerId: _selectedCustomer!.id,
          amount: cart.total,
          transactionId: transaction.id,
          staffId: '', // Will be filled by provider
          staffName: '',
        );
      }

      if (mounted) {
        // Navigate to receipt screen
        context.go('/receipt/${transaction.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final store = ref.watch(storeProvider).store;

    if (cart.isEmpty) {
      // Cart was cleared, go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Get GCash QR code from store settings
    final gcashQrUrl = store?.settings['gcashQrCode'] as String?;
    final mayaQrUrl = store?.settings['mayaQrCode'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Order Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Items', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('${cart.itemCount}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                    Text('${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tax (${(cart.taxRate * 100).toStringAsFixed(0)}%)',
                         style: TextStyle(color: AppColors.textSecondary)),
                    Text('${AppConstants.currencySymbol}${cart.tax.toStringAsFixed(2)}'),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      '${AppConstants.currencySymbol}${cart.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Payment Method Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PaymentMethodChip(
                        icon: Icons.payments,
                        label: 'Cash',
                        isSelected: _selectedPaymentMethod == PaymentMethod.cash,
                        onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.cash),
                      ),
                      const SizedBox(width: 8),
                      _PaymentMethodChip(
                        icon: Icons.phone_android,
                        label: 'GCash',
                        isSelected: _selectedPaymentMethod == PaymentMethod.gcash,
                        onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.gcash),
                      ),
                      const SizedBox(width: 8),
                      _PaymentMethodChip(
                        icon: Icons.account_balance_wallet,
                        label: 'Maya',
                        isSelected: _selectedPaymentMethod == PaymentMethod.maya,
                        onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.maya),
                      ),
                      const SizedBox(width: 8),
                      _PaymentMethodChip(
                        icon: Icons.credit_card,
                        label: 'Card',
                        isSelected: _selectedPaymentMethod == PaymentMethod.card,
                        onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.card),
                      ),
                      const SizedBox(width: 8),
                      _PaymentMethodChip(
                        icon: Icons.access_time,
                        label: 'Credit',
                        isSelected: _selectedPaymentMethod == PaymentMethod.credit,
                        onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.credit),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payment Method Content
          Expanded(
            child: _buildPaymentMethodContent(gcashQrUrl, mayaQrUrl, cart),
          ),

          // Complete Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Change (for cash)
                  if (_selectedPaymentMethod == PaymentMethod.cash && _amountReceived > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _change >= 0 ? 'Change' : 'Amount Due',
                            style: TextStyle(
                              fontSize: 16,
                              color: _change >= 0 ? AppColors.textSecondary : AppColors.error,
                            ),
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${_change.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _change >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Credit customer info
                  if (_selectedPaymentMethod == PaymentMethod.credit && _selectedCustomer != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCustomer!.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Current Balance: ${AppConstants.currencySymbol}${_selectedCustomer!.creditBalance.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _selectCustomer,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  // Complete Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canComplete ? _completeTransaction : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.success,
                        disabledBackgroundColor: AppColors.border,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _getCompleteButtonText(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCompleteButtonText() {
    switch (_selectedPaymentMethod) {
      case PaymentMethod.cash:
        return 'Complete Sale';
      case PaymentMethod.gcash:
        return 'Confirm GCash Payment';
      case PaymentMethod.maya:
        return 'Confirm Maya Payment';
      case PaymentMethod.card:
        return 'Complete Card Payment';
      case PaymentMethod.credit:
        return 'Add to Credit';
    }
  }

  Widget _buildPaymentMethodContent(String? gcashQrUrl, String? mayaQrUrl, CartState cart) {
    switch (_selectedPaymentMethod) {
      case PaymentMethod.cash:
        return _buildCashPayment(cart);
      case PaymentMethod.gcash:
        return _buildEWalletPayment('GCash', gcashQrUrl, const Color(0xFF007DFE));
      case PaymentMethod.maya:
        return _buildEWalletPayment('Maya', mayaQrUrl, const Color(0xFF00C853));
      case PaymentMethod.card:
        return _buildCardPayment();
      case PaymentMethod.credit:
        return _buildCreditPayment();
    }
  }

  Widget _buildCashPayment(CartState cart) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount Received',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _amountReceived >= cart.total
                    ? AppColors.success
                    : AppColors.border,
                width: 2,
              ),
            ),
            child: Text(
              _amountInput.isEmpty
                  ? '${AppConstants.currencySymbol}0.00'
                  : '${AppConstants.currencySymbol}$_amountInput',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _amountReceived >= cart.total
                    ? AppColors.success
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // Quick Amount Buttons
          Row(
            children: [
              _QuickAmountButton(
                label: 'Exact',
                onTap: _setExactAmount,
              ),
              const SizedBox(width: 8),
              _QuickAmountButton(
                label: '${AppConstants.currencySymbol}100',
                onTap: () => _setQuickAmount(100),
              ),
              const SizedBox(width: 8),
              _QuickAmountButton(
                label: '${AppConstants.currencySymbol}500',
                onTap: () => _setQuickAmount(500),
              ),
              const SizedBox(width: 8),
              _QuickAmountButton(
                label: '${AppConstants.currencySymbol}1000',
                onTap: () => _setQuickAmount(1000),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Numpad
          _Numpad(
            onDigit: _onDigitPressed,
            onBackspace: _onBackspace,
            onClear: _onClear,
          ),
        ],
      ),
    );
  }

  Widget _buildEWalletPayment(String name, String? qrUrl, Color brandColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // QR Code Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Scan to Pay with $name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: brandColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (qrUrl != null && qrUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: qrUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        width: 200,
                        height: 200,
                        color: AppColors.surfaceVariant,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code, size: 64, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              'QR Code not available',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No QR Code uploaded',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload in Store Settings',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Amount: ${AppConstants.currencySymbol}${ref.read(cartProvider).total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reference Number Input
          Text(
            'After payment, enter the reference number:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _referenceController,
            decoration: InputDecoration(
              labelText: 'Reference/Transaction Number',
              hintText: 'Enter $name reference number',
              prefixIcon: const Icon(Icons.tag),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: brandColor, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),
          Text(
            'This reference number will be recorded with the transaction for verification.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPayment() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card,
                size: 64,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Card Payment',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Process the card payment using your card terminal, then tap "Complete Card Payment" below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Amount: ${AppConstants.currencySymbol}${ref.read(cartProvider).total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditPayment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This transaction will be added to the customer\'s credit balance.',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Select Customer',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          if (_selectedCustomer == null)
            GestureDetector(
              onTap: _selectCustomer,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_add,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to Select Customer',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Customer must be selected for credit sales',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    child: Text(
                      _selectedCustomer!.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Current Balance: ${AppConstants.currencySymbol}${_selectedCustomer!.creditBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _selectedCustomer!.owesStore
                                ? AppColors.warning
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'New Balance: ${AppConstants.currencySymbol}${(_selectedCustomer!.creditBalance + ref.read(cartProvider).total).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _selectCustomer,
                    icon: const Icon(Icons.swap_horiz),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _NumpadButton(label: '1', onTap: () => onDigit('1')),
            _NumpadButton(label: '2', onTap: () => onDigit('2')),
            _NumpadButton(label: '3', onTap: () => onDigit('3')),
          ],
        ),
        Row(
          children: [
            _NumpadButton(label: '4', onTap: () => onDigit('4')),
            _NumpadButton(label: '5', onTap: () => onDigit('5')),
            _NumpadButton(label: '6', onTap: () => onDigit('6')),
          ],
        ),
        Row(
          children: [
            _NumpadButton(label: '7', onTap: () => onDigit('7')),
            _NumpadButton(label: '8', onTap: () => onDigit('8')),
            _NumpadButton(label: '9', onTap: () => onDigit('9')),
          ],
        ),
        Row(
          children: [
            _NumpadButton(label: '.', onTap: () => onDigit('.')),
            _NumpadButton(label: '0', onTap: () => onDigit('0')),
            _NumpadButton(
              label: '⌫',
              onTap: onBackspace,
              onLongPress: onClear,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NumpadButton({
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerSelector extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerSelector({required this.customers});

  @override
  State<_CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends State<_CustomerSelector> {
  final _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = widget.customers;
      } else {
        final q = query.toLowerCase();
        _filteredCustomers = widget.customers.where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.phone?.contains(q) ?? false)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filter,
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(customer.name),
                  subtitle: customer.phone != null
                      ? Text(customer.phone!)
                      : null,
                  trailing: customer.hasBalance
                      ? Text(
                          '${AppConstants.currencySymbol}${customer.creditBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, customer),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
