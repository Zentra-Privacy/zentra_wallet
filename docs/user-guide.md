# User guide

A practical walkthrough of Zentra Wallet for everyday use.

---

## Opening the app

### Splash screen

- Loads your saved network and wallet name
- If already set up, connects and syncs (60s timeout)
- On failure → you can fix the node in Settings or re-onboard

### First-time onboarding

Steps:

1. **Choose network** — Mainnet (real ZTR), Testnet, or Stagenet
2. **Node** — Mainnet: pick Seed 1 or Seed 2; Testnet/Stagenet: ensure local `zentrad` is running
3. **Wallet action** — one of:
   - **Create new wallet** — generates a new seed inside wallet2
   - **Restore from seed** — enter 12/13/24/25 word mnemonic
   - **Open existing** — open a wallet file already in `zentra_wallets/` with password

4. **Wallet details**
   - **Filename** — simple name only (no `/` or `\`), e.g. `my_wallet`
   - **Password** — at least 8 characters; encrypts wallet files on disk
   - **Restore height** (optional) — block height to start scanning (mainly for restore)

5. **Backup** — seed phrase shown once; write it down offline

After success you land on the **Home** screen.

---

## Home screen

Bottom tabs:

| Tab | Purpose |
|-----|---------|
| **Dashboard** | Balance, sync chip, address snippet, Send / Receive, recent txs |
| **Assets** | ZTR-focused asset view |
| **Transactions** | Full history list |
| **Settings** | Network, node, backup, restore height |

**Pull to refresh** on dashboard triggers blockchain rescan via wallet2.

### When can you send?

Send is enabled when:

- Wallet is **connected**
- Wallet height has caught up to daemon (not “behind” sync)

Otherwise the app asks you to wait for sync.

---

## Receive ZTR

1. Dashboard → **Receive** (or Assets flow)
2. Shows your primary address and QR code
3. Share address with sender — must match your network (Z/T/S prefix)

There is no separate “accounts” system in v1 — one primary address per wallet file.

---

## Send ZTR

1. Dashboard → **Send**
2. Enter recipient address (validated for current network)
3. Enter amount in **ZTR** display units
4. App estimates **network fee** (separate from amount)
5. Confirm — transaction is signed locally and relayed via daemon

On success you get a **txid** (transaction id hex).

**Priority:** default fee priority is used (see native FFI for priority levels 0–3 if extended in UI later).

---

## Transaction history

- **Incoming** and **outgoing** transfers from wallet2
- Shows amount, time, confirmations, pending/failed state
- Sorted newest first

History appears after sync scans relevant blocks — not from a block explorer API.

---

## Settings

### Connection card

- Status: disconnected / connecting / connected / error
- Sync progress when wallet is behind daemon
- Primary address chip when connected

### Wallet section

- **My Wallet** — current filename
- **Backup & seed phrase** — view address and seed (requires connected wallet)
- **Restore height** — change scan start block for open wallet

### Network section

- **Network** — switch mainnet / testnet / stagenet (must match wallet file)
- **Network node (zentrad)** — change daemon host:port or seed selection

### Other

- **Switch wallet** — return to onboarding to create/open/restore another file
- **About** — app version info

---

## Backup your wallet

Two layers:

1. **Seed phrase** (most important) — restores full access; shown in Backup screen
2. **Wallet files + password** — encrypted files in app data; password in secure storage

If you lose the device but have the **seed**, restore on a new install with the same network and a sensible restore height.

Never screenshot the seed to cloud albums or chat apps.

---

## Switching wallets

Settings → switch wallet flow → onboarding.

Each wallet is a separate filename under the app’s `zentra_wallets` directory. Password is stored per app install (last used wallet password in secure storage).

---

## Testnet usage

1. Run `zentrad` with testnet and RPC port **29081**
2. In app select **Testnet**
3. Create or restore a **testnet** wallet (addresses start with `T`)
4. Obtain test coins from a faucet or mining (see Zentra community docs)

Do not send mainnet ZTR to testnet addresses.

---

## Disabled features

- **Swap** — button visible but disabled; no swap integration in this version

---

## See also

- [Security](security.md)
- [Networks and nodes](networks-and-nodes.md)
- [FAQ](faq.md)
