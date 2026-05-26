/// Cake Wallet–style sync lifecycle for embedded wallet2.
enum WalletSyncStatus {
  disconnected,
  connecting,
  connected,
  attempting,
  syncing,
  synced,
}

/// Blocks behind daemon tip to treat wallet as fully synced (Cake uses ~100).
const int kWalletSyncedBlocksThreshold = 100;

/// UI / snapshot poll interval (Cake SyncListener ≈ 1200ms).
const Duration kWalletSyncPollInterval = Duration(milliseconds: 1200);

/// Debounced wallet file persist interval (Cake auto-save).
const Duration kWalletAutoStoreInterval = Duration(seconds: 30);
