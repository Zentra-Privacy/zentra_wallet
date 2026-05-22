# Security

How Zentra Wallet protects your funds and what you should do as a user.

---

## Threat model (simplified)

| Asset | Risk if lost/stolen |
|-------|---------------------|
| **Seed phrase** | Full loss of funds — treat like cash |
| **Wallet password** | Protects encrypted files on device; attacker with disk but no password needs brute force |
| **App unlock** | No separate PIN in v1 — OS session security matters |
| **Daemon operator** | Can affect sync privacy / potentially censor relay; does **not** get keys via this app’s design |

---

## What stays on your device

- Private keys (inside wallet2 wallet files)
- Seed phrase (shown only when you open backup; derived from wallet when connected)
- Transaction signing
- Encrypted wallet cache and keys file

The app does **not** upload the seed to a Zentra Wallet server — there is no such server in the architecture.

---

## Password storage

- **Wallet password** (encrypts wallet2 files): entered at create/restore/open; stored in **Flutter Secure Storage** for automatic reconnect
- Legacy passwords in SharedPreferences are **migrated** to secure storage on first read

Use a strong password unique to this wallet. The OS keychain protects the stored password from other apps.

---

## Wallet files on disk

Location (Linux example):

`~/.local/share/com.example.zentra_wallet/` → application support → `zentra_wallets/`

Files are in wallet2 format, encrypted with your wallet password. Copying files without the password is not enough to spend (but still handle backups carefully).

---

## Daemon trust

| Daemon | `trusted` flag |
|--------|----------------|
| `127.0.0.1`, `localhost`, `::1` | Yes |
| Public seed IPs | No |

An untrusted daemon is the normal mainnet default. Risks are aligned with Monero documentation (e.g. dishonest chain tip, metadata). Mitigation: **run your own `zentrad`** and point the wallet to it (or tunnel to localhost).

---

## Network privacy

- This is a **privacy coin** wallet; use mainnet seeds or your node with awareness of Monero-family remote node guidance
- The app does not implement Tor/i2p hooks in Flutter v1 — configure OS-level VPN/Tor if you need that layer

---

## Seed phrase rules

- Valid lengths: **12, 13, 24, or 25** words (English mnemonic style)
- Normalized whitespace before restore
- **25 words** is typical for Monero-family seeds (24 + checksum word)

Anyone with the seed can recreate your wallet on any compatible client.

---

## Backup best practices

1. Write seed on paper or metal backup — **offline**
2. Verify words carefully after restore on test amount first if unsure
3. Do not email, Discord, or cloud-drive the seed
4. Wallet password backup is secondary to seed — seed alone restores access

---

## What the app does not protect against

- Malware on your computer reading screen or memory
- Someone watching you type the password
- Sending ZTR to a wrong address (always verify address and network)
- Physical theft of unlocked device

---

## No wallet-RPC attack surface

Because the app never opens JSON-RPC to `zentra-wallet-rpc`, common remote wallet API misconfigurations (open 8082 on VPS) do not apply to this client.

Still secure your **daemon** RPC (firewall, non-public bind) on servers you operate.

---

## Reporting issues

If you find a security bug, report privately to the project maintainers rather than opening a public issue with exploit details.

---

## See also

- [Self-custody model](self-custody-model.md)
- [User guide](user-guide.md) — backup flow
- [FAQ](faq.md)
