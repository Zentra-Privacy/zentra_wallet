#include "zentra_wallet_ffi.h"

#include <wallet/api/wallet2_api.h>

#include <cstring>
#include <mutex>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>

namespace {

std::mutex g_mutex;
Monero::WalletManager* g_wm = nullptr;
std::string g_wallet_dir;
std::string g_daemon_address;
int g_trusted_daemon = 1;
std::string g_last_error;
thread_local std::string g_tl_error;

void set_error(const std::string& msg) {
  g_last_error = msg;
  g_tl_error = msg;
}

Monero::NetworkType to_net(int nettype) {
  switch (nettype) {
    case 1:
      return Monero::TESTNET;
    case 2:
      return Monero::STAGENET;
    default:
      return Monero::MAINNET;
  }
}

Monero::Wallet* as_wallet(ZentraWalletHandle h) {
  return reinterpret_cast<Monero::Wallet*>(h);
}

bool check_wallet(Monero::Wallet* w) {
  if (!w) {
    set_error("Wallet handle is null");
    return false;
  }
  if (w->status() != Monero::Wallet::Status_Ok) {
    set_error(w->errorString());
    return false;
  }
  return true;
}

/// wallet2::init — required before refresh/balance/daemon RPC (Monero/Cake flow).
bool bind_wallet_to_daemon(Monero::Wallet* w, bool persist) {
  if (!check_wallet(w)) return false;
  if (g_daemon_address.empty()) {
    set_error("Daemon address not set");
    return false;
  }
  if (!w->init(g_daemon_address, 0, "", "", false, false, "")) {
    const auto err = w->errorString();
    set_error(err.empty() ? "wallet init failed" : err);
    return false;
  }
  w->setTrustedDaemon(g_trusted_daemon != 0);
  if (persist && !w->store("")) {
    const auto err = w->errorString();
    set_error(err.empty() ? "wallet store failed" : err);
    return false;
  }
  return true;
}

char* dup_string(const std::string& s) {
  char* out = static_cast<char*>(std::malloc(s.size() + 1));
  if (!out) return nullptr;
  std::memcpy(out, s.c_str(), s.size() + 1);
  return out;
}

std::string json_escape(const std::string& s) {
  std::string out;
  out.reserve(s.size() + 8);
  for (char c : s) {
    if (c == '"' || c == '\\') {
      out += '\\';
    }
    out += c;
  }
  return out;
}

std::string full_path(const char* name) {
  if (!name || !*name) return {};
  std::string p(name);
  if (p.find('/') != std::string::npos || p.find('\\') != std::string::npos) {
    return p;
  }
  if (g_wallet_dir.empty()) return p;
  return g_wallet_dir + "/" + p;
}

}  // namespace

extern "C" {

ZENTRA_WM_API int zentra_wm_init(const char* wallet_dir) {
  std::lock_guard<std::mutex> lock(g_mutex);
  try {
    if (wallet_dir) {
      g_wallet_dir = wallet_dir;
      mkdir(wallet_dir, 0700);
    }
    if (!g_wm) {
      Monero::Utils::onStartup();
      g_wm = Monero::WalletManagerFactory::getWalletManager();
    }
    return g_wm ? 1 : 0;
  } catch (const std::exception& e) {
    set_error(e.what());
    return 0;
  }
}

ZENTRA_WM_API void zentra_wm_shutdown(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_wm = nullptr;
}

ZENTRA_WM_API void zentra_wm_set_daemon(const char* daemon_address, int trusted_daemon) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!daemon_address) return;
  g_daemon_address = daemon_address;
  g_trusted_daemon = trusted_daemon ? 1 : 0;
  if (g_wm) {
    g_wm->setDaemonAddress(daemon_address);
  }
}

ZENTRA_WM_API ZentraWalletHandle zentra_wm_create_wallet(
    const char* path,
    const char* password,
    int nettype) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_wm) {
    set_error("Wallet manager not initialized");
    return nullptr;
  }
  try {
    const auto full = full_path(path);
    auto* w = g_wm->createWallet(full, password ? password : "", "English", to_net(nettype));
    if (!check_wallet(w)) {
      if (w) g_wm->closeWallet(w, false);
      return nullptr;
    }
    if (!bind_wallet_to_daemon(w, true)) {
      g_wm->closeWallet(w, false);
      return nullptr;
    }
    return w;
  } catch (const std::exception& e) {
    set_error(e.what());
    return nullptr;
  }
}

ZENTRA_WM_API ZentraWalletHandle zentra_wm_open_wallet(
    const char* path,
    const char* password,
    int nettype) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_wm) {
    set_error("Wallet manager not initialized");
    return nullptr;
  }
  try {
    const auto full = full_path(path);
    auto* w = g_wm->openWallet(full, password ? password : "", to_net(nettype));
    if (!check_wallet(w)) {
      if (w) g_wm->closeWallet(w, false);
      return nullptr;
    }
    if (!bind_wallet_to_daemon(w, false)) {
      g_wm->closeWallet(w, false);
      return nullptr;
    }
    return w;
  } catch (const std::exception& e) {
    set_error(e.what());
    return nullptr;
  }
}

ZENTRA_WM_API ZentraWalletHandle zentra_wm_restore_wallet(
    const char* path,
    const char* password,
    const char* mnemonic,
    int nettype,
    uint64_t restore_height) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_wm) {
    set_error("Wallet manager not initialized");
    return nullptr;
  }
  try {
    const auto full = full_path(path);
    auto* w = g_wm->recoveryWallet(
        full,
        password ? password : "",
        mnemonic ? mnemonic : "",
        to_net(nettype),
        restore_height);
    if (!check_wallet(w)) {
      if (w) g_wm->closeWallet(w, false);
      return nullptr;
    }
    if (!bind_wallet_to_daemon(w, true)) {
      g_wm->closeWallet(w, false);
      return nullptr;
    }
    return w;
  } catch (const std::exception& e) {
    set_error(e.what());
    return nullptr;
  }
}

ZENTRA_WM_API void zentra_wm_close_wallet(ZentraWalletHandle wallet) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_wm || !wallet) return;
  g_wm->closeWallet(as_wallet(wallet), true);
}

ZENTRA_WM_API int zentra_wm_refresh(ZentraWalletHandle wallet) {
  std::lock_guard<std::mutex> lock(g_mutex);
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  try {
    return w->refresh() ? 1 : 0;
  } catch (const std::exception& e) {
    set_error(e.what());
    return 0;
  }
}

ZENTRA_WM_API int zentra_wm_start_background_refresh(ZentraWalletHandle wallet) {
  std::lock_guard<std::mutex> lock(g_mutex);
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  try {
    w->startRefresh();
    return 1;
  } catch (const std::exception& e) {
    set_error(e.what());
    return 0;
  }
}

ZENTRA_WM_API uint64_t zentra_wm_balance(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  return w->balanceAll();
}

ZENTRA_WM_API uint64_t zentra_wm_unlocked_balance(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  return w->unlockedBalanceAll();
}

ZENTRA_WM_API uint64_t zentra_wm_wallet_height(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  return w->blockChainHeight();
}

ZENTRA_WM_API uint64_t zentra_wm_daemon_height(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  return w->daemonBlockChainHeight();
}

ZENTRA_WM_API char* zentra_wm_address(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return nullptr;
  return dup_string(w->address());
}

ZENTRA_WM_API char* zentra_wm_seed(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return nullptr;
  return dup_string(w->seed());
}

ZENTRA_WM_API char* zentra_wm_send(
    ZentraWalletHandle wallet,
    const char* address,
    uint64_t amount_atomic) {
  std::lock_guard<std::mutex> lock(g_mutex);
  auto* w = as_wallet(wallet);
  if (!w || !address) {
    set_error("Invalid send parameters");
    return nullptr;
  }
  try {
    auto* tx = w->createTransaction(
        address,
        "",
        amount_atomic,
        16,
        Monero::PendingTransaction::Priority_Default);
    if (!tx || tx->status() != Monero::PendingTransaction::Status_Ok) {
      set_error(tx ? tx->errorString() : "createTransaction failed");
      if (tx) w->disposeTransaction(tx);
      return nullptr;
    }
    if (!tx->commit()) {
      set_error(tx->errorString());
      w->disposeTransaction(tx);
      return nullptr;
    }
    const auto ids = tx->txid();
    w->disposeTransaction(tx);
    if (ids.empty()) {
      set_error("No txid returned");
      return nullptr;
    }
    return dup_string(ids.front());
  } catch (const std::exception& e) {
    set_error(e.what());
    return nullptr;
  }
}

ZENTRA_WM_API int zentra_wm_store(ZentraWalletHandle wallet) {
  auto* w = as_wallet(wallet);
  if (!w) return 0;
  try {
    return w->store("") ? 1 : 0;
  } catch (const std::exception& e) {
    set_error(e.what());
    return 0;
  }
}

ZENTRA_WM_API char* zentra_wm_last_error(void) {
  return dup_string(g_last_error);
}

ZENTRA_WM_API void zentra_wm_free_string(char* ptr) {
  std::free(ptr);
}

ZENTRA_WM_API int zentra_wm_address_valid(const char* address, int nettype) {
  if (!address) return 0;
  return Monero::Wallet::addressValid(address, to_net(nettype)) ? 1 : 0;
}

ZENTRA_WM_API char* zentra_wm_transfers_json(ZentraWalletHandle wallet) {
  std::lock_guard<std::mutex> lock(g_mutex);
  auto* w = as_wallet(wallet);
  if (!w) {
    set_error("Wallet handle is null");
    return nullptr;
  }
  try {
    auto* hist = w->history();
    if (!hist) {
      return dup_string("[]");
    }
    hist->refresh();
    const auto all = hist->getAll();
    std::ostringstream oss;
    oss << "[";
    bool first = true;
    for (auto* ti : all) {
      if (!ti) continue;
      if (!first) oss << ",";
      first = false;
      const bool incoming =
          ti->direction() == Monero::TransactionInfo::Direction_In;
      oss << "{\"txid\":\"" << json_escape(ti->hash()) << "\""
          << ",\"amount\":" << ti->amount()
          << ",\"incoming\":" << (incoming ? "true" : "false")
          << ",\"timestamp\":"
          << static_cast<uint64_t>(ti->timestamp())
          << ",\"height\":" << ti->blockHeight()
          << ",\"confirmations\":" << ti->confirmations()
          << ",\"payment_id\":\"" << json_escape(ti->paymentId()) << "\""
          << ",\"pending\":" << (ti->isPending() ? "true" : "false")
          << ",\"failed\":" << (ti->isFailed() ? "true" : "false")
          << "}";
    }
    oss << "]";
    return dup_string(oss.str());
  } catch (const std::exception& e) {
    set_error(e.what());
    return nullptr;
  }
}

}  // extern "C"
