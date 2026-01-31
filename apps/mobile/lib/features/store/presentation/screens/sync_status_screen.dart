import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/connectivity_service.dart';
import '../../../../shared/services/sync_service.dart';
import '../../../../shared/services/offline_data_service.dart';

/// Screen showing sync status and pending operations
class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  Map<String, int>? _pendingCounts;
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadPendingCounts();
  }

  Future<void> _loadPendingCounts() async {
    setState(() => _isLoadingCounts = true);
    try {
      final offlineService = ref.read(offlineDataServiceProvider);
      final counts = await offlineService.getPendingSyncCounts();
      if (mounted) {
        setState(() {
          _pendingCounts = counts;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
    }
  }

  Future<void> _triggerSync() async {
    final syncNotifier = ref.read(syncProvider.notifier);
    await syncNotifier.syncNow();
    await _loadPendingCounts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectivity = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        actions: [
          if (connectivity.isOnline)
            IconButton(
              onPressed: syncState.isSyncing ? null : _triggerSync,
              icon: syncState.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              tooltip: 'Sync Now',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingCounts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection Status Card
            _buildConnectionCard(context, connectivity),

            const SizedBox(height: 16),

            // Sync Status Card
            _buildSyncStatusCard(context, syncState),

            const SizedBox(height: 16),

            // Pending Operations Card
            _buildPendingOperationsCard(context),

            const SizedBox(height: 16),

            // Last Sync Info
            _buildLastSyncCard(context, syncState),

            if (syncState.lastError != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(context, syncState.lastError!),
            ],

            const SizedBox(height: 24),

            // Manual Sync Button
            if (connectivity.isOnline)
              ElevatedButton.icon(
                onPressed: syncState.isSyncing ? null : _triggerSync,
                icon: syncState.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sync will automatically start when you\'re back online.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, ConnectivityState connectivity) {
    final isOnline = connectivity.isOnline;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isOnline
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          isOnline ? 'Online' : 'Offline',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          isOnline
              ? 'Connected to the internet'
              : connectivity.lastOnlineAt != null
                  ? 'Last online: ${_formatDateTime(connectivity.lastOnlineAt!)}'
                  : 'No internet connection',
        ),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    String status;
    String description;

    if (syncState.isSyncing) {
      icon = Icons.sync;
      color = Colors.blue;
      status = 'Syncing';
      description = 'Uploading pending changes...';
    } else if (syncState.pendingCount > 0) {
      icon = Icons.pending;
      color = Colors.orange;
      status = 'Pending';
      description = '${syncState.pendingCount} items waiting to sync';
    } else {
      icon = Icons.check_circle;
      color = Colors.green;
      status = 'Synced';
      description = 'All data is up to date';
    }

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: syncState.isSyncing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, color: color),
        ),
        title: Text(
          status,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildPendingOperationsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Operations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingCounts)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_pendingCounts == null)
              const Text('Unable to load pending counts')
            else ...[
              _buildPendingItem(
                context,
                'Transactions',
                _pendingCounts!['transactions'] ?? 0,
                Icons.receipt_long,
              ),
              const Divider(),
              _buildPendingItem(
                context,
                'Other Operations',
                _pendingCounts!['operations'] ?? 0,
                Icons.sync,
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pending',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (_pendingCounts!['total'] ?? 0) > 0
                          ? Colors.orange
                          : Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_pendingCounts!['total'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingItem(
    BuildContext context,
    String label,
    int count,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: count > 0 ? Colors.orange : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSyncCard(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.access_time, color: Colors.blue),
        ),
        title: Text(
          'Last Sync',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          syncState.lastSyncAt != null
              ? _formatDateTime(syncState.lastSyncAt!)
              : 'Never synced',
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      color: Colors.red.withValues(alpha: 0.1),
      child: ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: const Text(
          'Last Sync Error',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        subtitle: Text(
          error,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('MMM d, y HH:mm').format(dateTime);
    }
  }
}
