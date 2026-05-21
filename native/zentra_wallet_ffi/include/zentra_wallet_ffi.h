#pragma once

#include <stdint.h>

#if defined(_WIN32)
#define ZENTRA_WM_API __declspec(dllexport)
#else
#define ZENTRA_WM_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to Monero::Wallet
typedef void* ZentraWalletHandle;

/// 0=mainnet, 1=testnet, 2=stagenet (Monero::NetworkType)
ZENTRA_WM_API int zentra_wm_init(const char* wallet_dir);

ZENTRA_WM_API void zentra_wm_shutdown(void);

ZENTRA_WM_API void zentra_wm_set_daemon(const char* daemon_address, int trusted_daemon);

/// [restore_height] 0 = scan from genesis (new wallet). >0 = start scan at block.
ZENTRA_WM_API ZentraWalletHandle zentra_wm_create_wallet(
    const char* path,
    const char* password,
    int nettype,
    uint64_t restore_height);

ZENTRA_WM_API ZentraWalletHandle zentra_wm_open_wallet(
    const char* path,
    const char* password,
    int nettype);

ZENTRA_WM_API ZentraWalletHandle zentra_wm_restore_wallet(
    const char* path,
    const char* password,
    const char* mnemonic,
    int nettype,
    uint64_t restore_height);

ZENTRA_WM_API void zentra_wm_close_wallet(ZentraWalletHandle wallet);

ZENTRA_WM_API int zentra_wm_refresh(ZentraWalletHandle wallet);

ZENTRA_WM_API int zentra_wm_start_background_refresh(ZentraWalletHandle wallet);

ZENTRA_WM_API uint64_t zentra_wm_balance(ZentraWalletHandle wallet);

ZENTRA_WM_API uint64_t zentra_wm_unlocked_balance(ZentraWalletHandle wallet);

ZENTRA_WM_API uint64_t zentra_wm_wallet_height(ZentraWalletHandle wallet);

ZENTRA_WM_API uint64_t zentra_wm_daemon_height(ZentraWalletHandle wallet);

/// Caller must free with zentra_wm_free_string
ZENTRA_WM_API char* zentra_wm_address(ZentraWalletHandle wallet);

/// Caller must free with zentra_wm_free_string
ZENTRA_WM_API char* zentra_wm_seed(ZentraWalletHandle wallet);

/// Returns txid hex on success; caller frees. NULL on error.
ZENTRA_WM_API char* zentra_wm_send(
    ZentraWalletHandle wallet,
    const char* address,
    uint64_t amount_atomic);

ZENTRA_WM_API int zentra_wm_store(ZentraWalletHandle wallet);

ZENTRA_WM_API uint64_t zentra_wm_get_restore_height(ZentraWalletHandle wallet);

/// Updates refresh-from-block-height on an open wallet and persists it (clamped below daemon tip).
ZENTRA_WM_API int zentra_wm_set_restore_height(ZentraWalletHandle wallet, uint64_t height);

/// Last error message; caller frees.
ZENTRA_WM_API char* zentra_wm_last_error(void);

ZENTRA_WM_API void zentra_wm_free_string(char* ptr);

ZENTRA_WM_API int zentra_wm_address_valid(const char* address, int nettype);

/// JSON array of transfers from wallet2 TransactionHistory; caller frees.
ZENTRA_WM_API char* zentra_wm_transfers_json(ZentraWalletHandle wallet);

#ifdef __cplusplus
}
#endif
