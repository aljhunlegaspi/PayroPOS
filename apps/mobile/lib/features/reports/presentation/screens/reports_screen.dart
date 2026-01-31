import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/providers/transaction_provider.dart';

/// Date range filter options
enum DateRangeFilter { today, weekly, monthly, yearly, custom }

/// Reports state
class ReportsState {
  final DateRangeFilter filter;
  final DateTime startDate;
  final DateTime endDate;
  final bool isLoading;
  final String? error;
  final List<SaleTransaction> transactions;
  final double totalSales;
  final double totalCost;
  final double totalProfit;
  final int transactionCount;
  final double averageTransaction;
  final Map<String, double> salesByPaymentMethod;
  final List<TopProduct> topProducts;

  const ReportsState({
    this.filter = DateRangeFilter.today,
    required this.startDate,
    required this.endDate,
    this.isLoading = false,
    this.error,
    this.transactions = const [],
    this.totalSales = 0,
    this.totalCost = 0,
    this.totalProfit = 0,
    this.transactionCount = 0,
    this.averageTransaction = 0,
    this.salesByPaymentMethod = const {},
    this.topProducts = const [],
  });

  ReportsState copyWith({
    DateRangeFilter? filter,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLoading,
    String? error,
    List<SaleTransaction>? transactions,
    double? totalSales,
    double? totalCost,
    double? totalProfit,
    int? transactionCount,
    double? averageTransaction,
    Map<String, double>? salesByPaymentMethod,
    List<TopProduct>? topProducts,
  }) {
    return ReportsState(
      filter: filter ?? this.filter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      transactions: transactions ?? this.transactions,
      totalSales: totalSales ?? this.totalSales,
      totalCost: totalCost ?? this.totalCost,
      totalProfit: totalProfit ?? this.totalProfit,
      transactionCount: transactionCount ?? this.transactionCount,
      averageTransaction: averageTransaction ?? this.averageTransaction,
      salesByPaymentMethod: salesByPaymentMethod ?? this.salesByPaymentMethod,
      topProducts: topProducts ?? this.topProducts,
    );
  }
}

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;

  const TopProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

/// Reports notifier
class ReportsNotifier extends StateNotifier<ReportsState> {
  final Ref _ref;
  final SupabaseClient _supabase;

  ReportsNotifier(this._ref)
      : _supabase = Supabase.instance.client,
        super(ReportsState(
          startDate: DateTime.now(),
          endDate: DateTime.now(),
        )) {
    _loadReports();
  }

  void setFilter(DateRangeFilter filter) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (filter) {
      case DateRangeFilter.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangeFilter.weekly:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangeFilter.monthly:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangeFilter.yearly:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangeFilter.custom:
        return; // Custom dates set separately
    }

    state = state.copyWith(
      filter: filter,
      startDate: start,
      endDate: end,
    );
    _loadReports();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      filter: DateRangeFilter.custom,
      startDate: start,
      endDate: end,
    );
    _loadReports();
  }

  Future<void> _loadReports() async {
    final store = _ref.read(storeProvider).store;
    if (store == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('store_id', store.id)
          .gte('created_at', state.startDate.toIso8601String())
          .lte('created_at', state.endDate.toIso8601String())
          .order('created_at', ascending: false);

      final transactions = (response as List)
          .map((data) => SaleTransaction.fromSupabase(data))
          .toList();

      // Calculate metrics
      final totalSales = transactions.fold<double>(0, (sum, t) => sum + t.total);
      final totalCost = transactions.fold<double>(0, (sum, t) =>
        sum + t.items.fold<double>(0, (itemSum, item) => itemSum + item.totalCost));
      final totalProfit = totalSales - totalCost;
      final transactionCount = transactions.length;
      final averageTransaction = transactionCount > 0 ? totalSales / transactionCount : 0.0;

      // Sales by payment method
      final salesByMethod = <String, double>{};
      for (final t in transactions) {
        salesByMethod[t.paymentMethod] =
            (salesByMethod[t.paymentMethod] ?? 0) + t.total;
      }

      // Top products
      final productSales = <String, Map<String, dynamic>>{};
      for (final t in transactions) {
        for (final item in t.items) {
          if (productSales.containsKey(item.productId)) {
            productSales[item.productId]!['quantity'] += item.quantity;
            productSales[item.productId]!['revenue'] += item.subtotal;
          } else {
            productSales[item.productId] = {
              'name': item.name,
              'quantity': item.quantity,
              'revenue': item.subtotal,
            };
          }
        }
      }

      final topProducts = productSales.entries
          .map((e) => TopProduct(
                name: e.value['name'],
                quantity: e.value['quantity'],
                revenue: e.value['revenue'],
              ))
          .toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      state = state.copyWith(
        isLoading: false,
        transactions: transactions,
        totalSales: totalSales,
        totalCost: totalCost,
        totalProfit: totalProfit,
        transactionCount: transactionCount,
        averageTransaction: averageTransaction,
        salesByPaymentMethod: salesByMethod,
        topProducts: topProducts.take(10).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => _loadReports();
}

final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  return ReportsNotifier(ref);
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // Decorative Header
          _buildDecorativeHeader(context, ref, reports),

          // Content with rounded top corners
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: reports.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => ref.read(reportsProvider.notifier).refresh(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary Cards
                              _buildSummaryCards(reports),
                              const SizedBox(height: 24),

                              // Sales by Payment Method
                              if (reports.salesByPaymentMethod.isNotEmpty) ...[
                                _buildSectionTitle('Sales by Payment Method'),
                                const SizedBox(height: 12),
                                _buildPaymentMethodCard(reports),
                                const SizedBox(height: 24),
                              ],

                              // Top Products
                              if (reports.topProducts.isNotEmpty) ...[
                                _buildSectionTitle('Top Products'),
                                const SizedBox(height: 12),
                                _buildTopProductsCard(reports),
                                const SizedBox(height: 24),
                              ],

                              // Recent Transactions
                              _buildSectionTitle('Recent Transactions'),
                              const SizedBox(height: 12),
                              _buildTransactionsList(reports),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeHeader(BuildContext context, WidgetRef ref, ReportsState reports) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative shapes
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryMuted.withValues(alpha: 0.3),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 80,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            // Header content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  // Top row with back button
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.go('/home'),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => ref.read(reportsProvider.notifier).refresh(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales Reports',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Track your business performance',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date filter dropdown
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DateRangeFilter>(
                              value: reports.filter,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                              dropdownColor: Colors.white,
                              items: DateRangeFilter.values.map((filter) {
                                return DropdownMenuItem<DateRangeFilter>(
                                  value: filter,
                                  child: Text(
                                    _getFilterLabel(filter),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (filter) {
                                if (filter != null) {
                                  if (filter == DateRangeFilter.custom) {
                                    _showDateRangePicker(context, ref);
                                  } else {
                                    ref.read(reportsProvider.notifier).setFilter(filter);
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      if (reports.filter == DateRangeFilter.custom) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showDateRangePicker(context, ref),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (reports.filter == DateRangeFilter.custom) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_formatDateShort(reports.startDate)} - ${_formatDateShort(reports.endDate)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel(DateRangeFilter filter) {
    switch (filter) {
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.weekly:
        return 'Weekly';
      case DateRangeFilter.monthly:
        return 'Monthly';
      case DateRangeFilter.yearly:
        return 'Yearly';
      case DateRangeFilter.custom:
        return 'Custom';
    }
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Future<void> _showDateRangePicker(BuildContext context, WidgetRef ref) async {
    final reports = ref.read(reportsProvider);
    final initialRange = DateTimeRange(
      start: reports.startDate,
      end: reports.endDate,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(reportsProvider.notifier).setCustomDateRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    }
  }

  Widget _buildSummaryCards(ReportsState reports) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.attach_money,
                label: 'Total Sales (Gross)',
                value: '${AppConstants.currencySymbol}${reports.totalSales.toStringAsFixed(2)}',
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.trending_up,
                label: 'Total Profit (Net)',
                value: '${AppConstants.currencySymbol}${reports.totalProfit.toStringAsFixed(2)}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.receipt_long,
                label: 'Transactions',
                value: '${reports.transactionCount}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.shopping_bag,
                label: 'Avg. Transaction',
                value: '${AppConstants.currencySymbol}${reports.averageTransaction.toStringAsFixed(2)}',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.inventory_2,
                label: 'Items Sold',
                value: '${reports.transactions.fold<int>(0, (sum, t) => sum + t.items.fold<int>(0, (s, i) => s + i.quantity))}',
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.price_change,
                label: 'Total Cost',
                value: '${AppConstants.currencySymbol}${reports.totalCost.toStringAsFixed(2)}',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPaymentMethodCard(ReportsState reports) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: reports.salesByPaymentMethod.entries.map((entry) {
            final percentage = reports.totalSales > 0
                ? (entry.value / reports.totalSales * 100)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getPaymentIcon(entry.key),
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getPaymentLabel(entry.key),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        '${AppConstants.currencySymbol}${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(_getPaymentColor(entry.key)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.payments;
      case 'card':
      case 'credit_card':
        return Icons.credit_card;
      case 'gcash':
        return Icons.phone_android;
      case 'maya':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
      case 'credit_card':
        return 'Card';
      case 'gcash':
        return 'GCash';
      case 'maya':
        return 'Maya';
      default:
        return method;
    }
  }

  Color _getPaymentColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'card':
      case 'credit_card':
        return AppColors.info;
      case 'gcash':
        return const Color(0xFF007DFE);
      case 'maya':
        return const Color(0xFF00C853);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildTopProductsCard(ReportsState reports) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: reports.topProducts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = reports.topProducts[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${product.quantity} sold'),
            trailing: Text(
              '${AppConstants.currencySymbol}${product.revenue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList(ReportsState reports) {
    if (reports.transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: math.min(reports.transactions.length, 10),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final transaction = reports.transactions[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt,
                color: AppColors.success,
                size: 20,
              ),
            ),
            title: Text(
              transaction.receiptNumber,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${transaction.items.length} items - ${_formatDateTime(transaction.createdAt)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: Text(
              '${AppConstants.currencySymbol}${transaction.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            onTap: () {
              context.push('/receipt/${transaction.id}');
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(dt.year, dt.month, dt.day);

    if (transactionDate == today) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
