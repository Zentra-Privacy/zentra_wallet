import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui_format.dart';
import '../../theme/zentra_theme.dart';

void zentraSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? ZentraTheme.danger : ZentraTheme.card,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

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

/// Tappable card for onboarding choices (create / restore / open).
class ZentraChoiceCard extends StatelessWidget {
  const ZentraChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  /// Single-line row: icon + short label only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZentraTheme.radiusMd),
      side: BorderSide(
        color: selected ? ZentraTheme.accent : ZentraTheme.border,
        width: selected ? 1.5 : 1,
      ),
    );

    if (compact) {
      return Material(
        color: selected ? ZentraTheme.accent.withValues(alpha: 0.12) : ZentraTheme.card,
        shape: border,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZentraTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? ZentraTheme.accent : ZentraTheme.textMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? ZentraTheme.textPrimary : ZentraTheme.textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: selected ? ZentraTheme.accent.withValues(alpha: 0.12) : ZentraTheme.card,
      shape: border,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZentraTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? ZentraTheme.accent.withValues(alpha: 0.2)
                      : ZentraTheme.surface,
                  borderRadius: BorderRadius.circular(ZentraTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? ZentraTheme.accent : ZentraTheme.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 12, color: ZentraTheme.textMuted, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? ZentraTheme.accent : ZentraTheme.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groups onboarding form fields in a single card.
class ZentraFormCard extends StatelessWidget {
  const ZentraFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ZentraTheme.flatCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            children[i],
          ],
        ],
      ),
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
          ?trailing,
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
    this.lockedZtr,
    this.secondaryLabel,
  });

  final String amountZtr;
  final String? unlockedZtr;
  final String? lockedZtr;
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
          if (unlockedZtr != null || lockedZtr != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (unlockedZtr != null)
              Row(
                children: [
                  const Icon(Icons.lock_open_outlined, size: 16, color: ZentraTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Unlocked $unlockedZtr', style: const TextStyle(fontSize: 13, color: ZentraTheme.textMuted)),
                  ),
                ],
              ),
            if (lockedZtr != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: ZentraTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Locked $lockedZtr — waiting for confirmations (~10 blocks)',
                      style: const TextStyle(fontSize: 12, color: ZentraTheme.textMuted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
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
          opacity: item.enabled ? 1 : 0.45,
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
  const ZentraSyncBanner({
    super.key,
    required this.message,
    this.isError = false,
    this.progress,
    this.subtitle,
  });

  final String message;
  final bool isError;
  final double? progress;
  final String? subtitle;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isError ? Icons.error_outline : Icons.sync, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: const TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (progress != null && !isError) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: ZentraTheme.border,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ZentraConnectionChip extends StatelessWidget {
  const ZentraConnectionChip({super.key, required this.label, this.isError = false, this.isSyncing = false});

  final String label;
  final bool isError;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? ZentraTheme.danger
        : isSyncing
            ? ZentraTheme.accent
            : ZentraTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class ZentraEmptyState extends StatelessWidget {
  const ZentraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: ZentraTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 13, height: 1.4),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class ZentraCopyField extends StatelessWidget {
  const ZentraCopyField({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 3,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: ZentraTheme.flatCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                value.isEmpty ? '—' : value,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      zentraSnack(context, '$label copied');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ZentraAddressChip extends StatelessWidget {
  const ZentraAddressChip({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    if (address.isEmpty) return const SizedBox.shrink();
    final short = UiFormat.truncateMiddle(address);
    return Material(
      color: ZentraTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: address));
          zentraSnack(context, 'Address copied');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZentraTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: ZentraTheme.textMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(short, style: const TextStyle(fontSize: 12, color: ZentraTheme.textMuted)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.copy, size: 14, color: ZentraTheme.accent),
            ],
          ),
        ),
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
    this.pending = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool isIncoming;
  final bool showDivider;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isIncoming ? ZentraTheme.success : ZentraTheme.textPrimary;
    final row = Padding(
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
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (pending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZentraTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Pending', style: TextStyle(fontSize: 10, color: ZentraTheme.accent)),
                      ),
                    ],
                  ],
                ),
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
    );
    return Column(
      children: [
        if (onTap != null)
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: row),
          )
        else
          row,
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
