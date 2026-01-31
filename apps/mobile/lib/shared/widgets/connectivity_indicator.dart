import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

/// A widget that displays the current network connectivity status
class ConnectivityIndicator extends ConsumerWidget {
  /// Whether to show the indicator as a banner at the top of the screen
  final bool showAsBanner;

  /// Whether to show the pending sync count
  final bool showSyncCount;

  const ConnectivityIndicator({
    super.key,
    this.showAsBanner = false,
    this.showSyncCount = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncProvider);

    if (showAsBanner) {
      return _buildBanner(context, connectivityState, syncState);
    }

    return _buildChip(context, connectivityState, syncState);
  }

  Widget _buildBanner(
    BuildContext context,
    ConnectivityState connectivity,
    SyncState sync,
  ) {
    // Only show banner when offline
    if (connectivity.isOnline && sync.pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isOffline = connectivity.isOffline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isOffline || sync.pendingCount > 0 ? 36 : 0,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.orange.shade700
            : sync.isSyncing
                ? Colors.blue.shade600
                : Colors.green.shade600,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isOffline) ...[
            const Icon(
              Icons.cloud_off,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Offline Mode',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showSyncCount && sync.pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${sync.pendingCount} pending',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ] else if (sync.isSyncing) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Syncing...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (sync.pendingCount > 0) ...[
            const Icon(
              Icons.sync,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '${sync.pendingCount} pending sync',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    ConnectivityState connectivity,
    SyncState sync,
  ) {
    final isOffline = connectivity.isOffline;

    if (connectivity.isOnline && sync.pendingCount == 0 && !sync.isSyncing) {
      // Show small online indicator
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Online',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.orange.withValues(alpha: 0.1)
            : sync.isSyncing
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffline
              ? Colors.orange.withValues(alpha: 0.3)
              : sync.isSyncing
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOffline)
            const Icon(Icons.cloud_off, color: Colors.orange, size: 16)
          else if (sync.isSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          else
            const Icon(Icons.cloud_done, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(
            isOffline
                ? 'Offline'
                : sync.isSyncing
                    ? 'Syncing'
                    : 'Online',
            style: TextStyle(
              fontSize: 12,
              color: isOffline
                  ? Colors.orange
                  : sync.isSyncing
                      ? Colors.blue
                      : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showSyncCount && sync.pendingCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${sync.pendingCount}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A wrapper widget that shows connectivity status at the top of the screen
class ConnectivityWrapper extends ConsumerWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const ConnectivityIndicator(showAsBanner: true),
        Expanded(child: child),
      ],
    );
  }
}

/// A small offline badge that can be shown on receipts or items
class OfflineBadge extends StatelessWidget {
  final bool isOffline;

  const OfflineBadge({
    super.key,
    this.isOffline = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: Colors.orange, size: 12),
          SizedBox(width: 4),
          Text(
            'Pending Sync',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a snackbar when connectivity changes
void showConnectivitySnackbar(BuildContext context, bool isOnline) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(isOnline ? 'Back online' : 'You are offline'),
        ],
      ),
      backgroundColor: isOnline ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
