import 'package:flutter/material.dart';

import '../../theme/zentra_theme.dart';

class ZentraLogo extends StatelessWidget {
  const ZentraLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ZentraTheme.accent,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.shield_outlined, size: size * 0.48, color: Colors.white),
    );
  }
}

class ZentraScaffold extends StatelessWidget {
  const ZentraScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZentraTheme.background,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Back-compat name
typedef ZentraGradientScaffold = ZentraScaffold;

class ZentraPageHeader extends StatelessWidget {
  const ZentraPageHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ZentraDashboardHeader extends StatelessWidget {
  const ZentraDashboardHeader({
    super.key,
    required this.title,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final String title;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return ZentraPageHeader(
      title: title,
      trailing: isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
            )
          : IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 22, color: ZentraTheme.textMuted),
              tooltip: 'Refresh',
            ),
    );
  }
}

class ZentraHeroBalanceCard extends StatelessWidget {
  const ZentraHeroBalanceCard({
    super.key,
    required this.amountZtr,
    this.unlockedZtr,
    this.secondaryLabel,
  });

  final String amountZtr;
  final String? unlockedZtr;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: ZentraTheme.pagePadding,
      padding: const EdgeInsets.all(20),
      decoration: ZentraTheme.flatCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Total balance', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13)),
              const Spacer(),
              if (secondaryLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZentraTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ZentraTheme.border),
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: const TextStyle(fontSize: 11, color: ZentraTheme.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(amountZtr, style: Theme.of(context).textTheme.headlineLarge),
          if (unlockedZtr != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock_open_outlined, size: 16, color: ZentraTheme.textMuted),
                const SizedBox(width: 8),
                Text('Unlocked $unlockedZtr', style: const TextStyle(fontSize: 13, color: ZentraTheme.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ZentraQuickActionsRow extends StatelessWidget {
  const ZentraQuickActionsRow({super.key, required this.actions});

  final List<ZentraQuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ZentraTheme.pagePadding,
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: ZentraQuickActionButton(item: actions[i])),
          ],
        ],
      ),
    );
  }
}

class ZentraQuickActionItem {
  const ZentraQuickActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
}

class ZentraQuickActionButton extends StatelessWidget {
  const ZentraQuickActionButton({super.key, required this.item});

  final ZentraQuickActionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZentraTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZentraTheme.radiusMd),
        side: const BorderSide(color: ZentraTheme.border),
      ),
      child: InkWell(
        onTap: item.enabled ? item.onTap : null,
        borderRadius: BorderRadius.circular(ZentraTheme.radiusMd),
        child: Opacity(
          opacity: item.enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(item.icon, color: ZentraTheme.accent, size: 22),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ZentraTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ZentraSectionHeader extends StatelessWidget {
  const ZentraSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: ZentraTheme.accent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

class ZentraSyncBanner extends StatelessWidget {
  const ZentraSyncBanner({super.key, required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? ZentraTheme.danger : ZentraTheme.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZentraTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, height: 1.4, color: ZentraTheme.textPrimary))),
        ],
      ),
    );
  }
}

class ZentraBottomNav extends StatelessWidget {
  const ZentraBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home, 'Home'),
      (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Assets'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
      (Icons.settings_outlined, Icons.settings, 'Settings'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: ZentraTheme.surface,
        border: Border(top: BorderSide(color: ZentraTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          currentIndex == i ? items[i].$2 : items[i].$1,
                          size: 22,
                          color: currentIndex == i ? ZentraTheme.accent : ZentraTheme.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: currentIndex == i ? FontWeight.w600 : FontWeight.w400,
                            color: currentIndex == i ? ZentraTheme.accent : ZentraTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clean list row for transactions.
class ZentraTxRow extends StatelessWidget {
  const ZentraTxRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncoming,
    this.showDivider = true,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool isIncoming;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = isIncoming ? ZentraTheme.success : ZentraTheme.textPrimary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZentraTheme.surface,
                  borderRadius: BorderRadius.circular(ZentraTheme.radiusSm),
                  border: Border.all(color: ZentraTheme.border),
                ),
                child: Icon(
                  isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 18,
                  color: isIncoming ? ZentraTheme.success : ZentraTheme.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: ZentraTheme.textMuted)),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 74, endIndent: 20),
      ],
    );
  }
}

class ZentraSettingsTile extends StatelessWidget {
  const ZentraSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: ZentraTheme.textMuted, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12))
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 20, color: ZentraTheme.textMuted) : null),
    );
  }
}

typedef ZentraBalanceCard = ZentraHeroBalanceCard;
typedef ZentraActionButton = ZentraQuickActionButton;
