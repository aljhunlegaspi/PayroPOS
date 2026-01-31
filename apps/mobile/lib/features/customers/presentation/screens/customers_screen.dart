import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/customer_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all'; // all, with_balance, no_balance

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _getFilteredCustomers(CustomerState state) {
    var customers = state.customers;

    // Apply filter
    if (_filter == 'with_balance') {
      customers = customers.where((c) => c.hasBalance).toList();
    } else if (_filter == 'no_balance') {
      customers = customers.where((c) => !c.hasBalance).toList();
    }

    // Apply search
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      customers = customers.where((c) =>
          c.name.toLowerCase().contains(query) ||
          (c.phone?.contains(query) ?? false) ||
          (c.email?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return customers;
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerProvider);
    final filteredCustomers = _getFilteredCustomers(customerState);
    final totalOwed = ref.watch(totalOwedProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // Decorative Header
          _buildDecorativeHeader(totalOwed),

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
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search customers...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _filter == 'all',
                            onSelected: (_) => setState(() => _filter = 'all'),
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('With Balance'),
                            selected: _filter == 'with_balance',
                            onSelected: (_) => setState(() => _filter = 'with_balance'),
                            selectedColor: AppColors.warning.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('No Balance'),
                            selected: _filter == 'no_balance',
                            onSelected: (_) => setState(() => _filter = 'no_balance'),
                            selectedColor: AppColors.success.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Customer List
                    Expanded(
                      child: customerState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredCustomers.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                  onRefresh: () => ref.read(customerProvider.notifier).refresh(),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: filteredCustomers.length,
                                    itemBuilder: (context, index) {
                                      final customer = filteredCustomers[index];
                                      return _CustomerCard(
                                        customer: customer,
                                        onTap: () => context.push('/customers/${customer.id}'),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Customer', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDecorativeHeader(double totalOwed) {
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
                          Icons.people_outline,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customers',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (totalOwed > 0)
                              Text(
                                'Total Receivables: ${AppConstants.currencySymbol}${totalOwed.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.accentLime,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              const Text(
                                'Manage your customers',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No customers found'
                : 'No customers yet',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first customer to get started',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: customer.hasBalance
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                radius: 24,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: customer.hasBalance
                        ? AppColors.warning
                        : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (customer.phone != null && customer.phone!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (customer.hasBalance) ...[
                    Text(
                      customer.owesStore ? 'Owes' : 'Credit',
                      style: TextStyle(
                        fontSize: 11,
                        color: customer.owesStore
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${customer.creditBalance.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: customer.owesStore
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No Balance',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
