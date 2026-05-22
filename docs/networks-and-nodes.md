# Networks and nodes

How Zentra networks work in the wallet and how to connect to a **daemon** (`zentrad`).

---

## Networks at a glance

| Network | Label | Address prefix | Daemon RPC port | Typical daemon setup |
|---------|-------|----------------|-----------------|----------------------|
| **Mainnet** | Mainnet | `Z` | **19081** | Public seed nodes or your VPS |
| **Testnet** | Testnet | `T` | **29081** | Local `zentrad` on same machine |
| **Stagenet** | Stagenet | `S` | **39081** | Local `zentrad` |

Address prefixes are enforced in the light `zentra_core` plugin and again in wallet2 before send.

---

## Mainnet public seed nodes

Built into the app (`lib/core/network/zentra_public_nodes.dart`):

| ID | Label | Host | Port | DNS (informational) |
|----|-------|------|------|------------------------|
| `seed1` | Seed 1 | `185.182.185.127` | 19081 | seed.zentraprivacy.org |
| `seed2` | Seed 2 | `213.136.78.112` | 19081 | seed1.zentraprivacy.org |

On first mainnet setup you pick one of these (or enter a custom `host:port` later in Settings).

These nodes are **untrusted** daemons — wallet2 still keeps keys local; see [Security](security.md).

---

## Testnet and stagenet

Defaults in settings:

```text
127.0.0.1:29081   # testnet
127.0.0.1:39081   # stagenet
```

You should run `zentrad` locally, for example:

```bash
# From your Zentra build (example — see Zentra docs for exact flags)
zentrad --testnet --rpc-bind-port=29081
```

The wallet marks **localhost** daemons as **trusted**.

---

## Daemon address format

Always **`host:port`** — no `http://` prefix.

Examples:

- `185.182.185.127:19081`
- `127.0.0.1:29081`
- `my-node.example.com:19081`

Parsed by `RpcAddress` in `lib/core/network/rpc_address.dart`. Invalid strings are rejected in the node setup screen.

---

## Changing the node in the app

1. Open **Settings**
2. Tap **Network node (zentrad)** → `NodeSetupScreen`
3. Mainnet: choose seed 1/2 or custom host:port
4. Save — reconnects wallet with new daemon via `setDaemon()`

If sync fails after a change, check firewall, that `zentrad` is running, and that the port matches the network.

---

## Running your own mainnet node (recommended for privacy)

On a VPS or home server:

1. Build and run `zentrad` for mainnet with RPC reachable (restrict firewall to your IP if possible)
2. In the wallet, set custom node to `your-server:19081`
3. Benefit: **trusted** flag if you use SSH tunnel to localhost, or at least you control the node

The wallet does **not** require wallet-RPC (`8082`) on that server — only daemon RPC.

---

## Sync and restore height

**Restore height** (also called refresh-from-block-height) tells wallet2 where to start scanning the chain. Lower wrong height = missing funds in UI; too low on new wallet = slow first sync.

- New wallet: height `0` scans from genesis (slow on mainnet)
- Restored wallet: set height near your first ZTRA receive (faster)
- Settings → **Restore height** panel updates open wallet and default for new restores

Use the optional field during onboarding restore, or adjust later in Settings.

---

## Network vs wallet file

A wallet file is tied to the **network type** it was created on. The app refuses to open a mainnet wallet while the UI is set to testnet (and vice versa). Switch network in Settings only when using a wallet created for that network.

---

## What the daemon does NOT do

- Hold your seed or spend keys
- Replace the wallet app
- Act as `zentra-wallet-rpc` for this Flutter client

It only provides **blockchain** data and **transaction relay**.

---

## See also

- [Self-custody model](self-custody-model.md)
- [Troubleshooting](troubleshooting.md) — sync timeouts
- [User guide](user-guide.md) — node setup during onboarding
