#pragma once

#include <stdint.h>

#if defined(_WIN32)
#define ZENTRA_API __declspec(dllexport)
#else
#define ZENTRA_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Network: 0=mainnet, 1=testnet, 2=stagenet
enum ZentraNetwork {
  ZENTRA_MAINNET = 0,
  ZENTRA_TESTNET = 1,
  ZENTRA_STAGENET = 2,
};

#define ZENTRA_ATOMIC_UNITS 1000000000ULL
#define ZENTRA_DISPLAY_DECIMALS 9

/// Returns 1 if address has valid length and expected base58 prefix for network.
ZENTRA_API int zentra_validate_address(const char* address, int network);

/// Convert atomic units to display string (caller must free with zentra_free_string).
ZENTRA_API char* zentra_atomic_to_display(uint64_t atomic);

/// Parse display amount to atomic units. Returns 0 on failure.
ZENTRA_API uint64_t zentra_display_to_atomic(const char* display);

/// Free strings returned by zentra_atomic_to_display.
ZENTRA_API void zentra_free_string(char* ptr);

/// Daemon RPC port for network (remote zentrad sync only).
ZENTRA_API uint16_t zentra_daemon_rpc_port(int network);

/// Address prefix character for standard address (Z/T/S).
ZENTRA_API char zentra_address_prefix_char(int network);

/// Coin ticker: always "ZTR".
ZENTRA_API const char* zentra_coin_ticker(void);

#ifdef __cplusplus
}
#endif
