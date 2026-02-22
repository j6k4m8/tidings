import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/account_models.dart';
import '../../state/app_state.dart';
import '../../state/qr_transfer.dart';
import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';

/// Shows the QR transfer dialog.  Call this from the accounts settings page.
Future<void> showQrTransferDialog(
  BuildContext context, {
  required AppState appState,
  required Color accent,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _QrTransferDialog(appState: appState, accent: accent),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _QrTransferDialog extends StatefulWidget {
  const _QrTransferDialog({required this.appState, required this.accent});
  final AppState appState;
  final Color accent;

  @override
  State<_QrTransferDialog> createState() => _QrTransferDialogState();
}

class _QrTransferDialogState extends State<_QrTransferDialog> {
  // Which accounts are checked for inclusion.
  late final Map<String, bool> _selected;
  // Whether to include app settings in the QR.
  bool _includeSettings = true;
  // The currently-displayed QR payload string (refreshed every 5 min).
  String? _qrData;
  // Seconds remaining until current QR expires.
  int _secondsLeft = 0;
  Timer? _countdownTimer;
  Timer? _refreshTimer;
  // Cached settings map (rebuilt on every QR generation from current context).
  Map<String, Object?>? _settingsSnapshot;

  static const _kExpirySeconds = 5 * 60;

  @override
  void initState() {
    super.initState();
    // Default: all real (non-mock) accounts selected.
    _selected = {
      for (final a in widget.appState.accounts)
        if (a.providerType != EmailProviderType.mock) a.id: true,
    };
    // QR is built in didChangeDependencies once context is available.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Snapshot the current settings so the QR reflects them at generation time.
    _settingsSnapshot = context.tidingsSettings.transferableSettingsMap();
    if (_qrData == null) _buildQr();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── QR generation ──────────────────────────────────────────────────────────

  void _buildQr() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();

    final selectedAccounts = widget.appState.accounts
        .where((a) => _selected[a.id] == true)
        .toList();

    final payloads = <QrTransferPayload>[];

    // Account payloads.
    for (final account in selectedAccounts) {
      if (account.providerType == EmailProviderType.imap &&
          account.imapConfig != null) {
        payloads.add(ImapQrPayload.fromAccount(account, account.imapConfig!));
      } else if (account.providerType == EmailProviderType.gmail) {
        payloads.add(GmailQrPayload(email: account.email));
      }
    }

    // Settings payload.
    if (_includeSettings && _settingsSnapshot != null) {
      payloads.add(SettingsQrPayload(settings: _settingsSnapshot!));
    }

    if (payloads.isEmpty) {
      setState(() {
        _qrData = null;
        _secondsLeft = 0;
      });
      return;
    }

    final data = payloads.length == 1
        ? payloads.first.encode()
        : _encodeMulti(payloads);

    setState(() {
      _qrData = data;
      _secondsLeft = _kExpirySeconds;
    });

    // Countdown every second.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(
          () => _secondsLeft = (_secondsLeft - 1).clamp(0, _kExpirySeconds));
    });

    // Regenerate slightly before expiry so the scanner never sees a stale code.
    _refreshTimer = Timer(
      const Duration(seconds: _kExpirySeconds - 10),
      _buildQr,
    );
  }

  /// Encodes multiple payloads joined with the multi-prefix format.
  static String _encodeMulti(List<QrTransferPayload> payloads) {
    final joined = payloads.map((p) => p.encode()).join(',');
    return 'multi:[$joined]';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool get _hasAnythingSelected =>
      _selected.values.any((v) => v) || _includeSettings;

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accounts = widget.appState.accounts
        .where((a) => a.providerType != EmailProviderType.mock)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          variant: GlassVariant.sheet,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transfer to mobile',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan this QR code in Tidings on your phone to import accounts and settings.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: ColorTokens.textSecondary(context),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Account picker ─────────────────────────────────────────
                if (accounts.isNotEmpty) ...[
                  _SectionLabel(label: 'Accounts', accent: widget.accent),
                  const SizedBox(height: 8),
                  _CheckGroup(
                    children: [
                      for (int i = 0; i < accounts.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: ColorTokens.border(context, 0.08),
                          ),
                        _AccountCheckRow(
                          account: accounts[i],
                          checked: _selected[accounts[i].id] ?? false,
                          onChanged: (val) {
                            setState(() => _selected[accounts[i].id] = val);
                            _buildQr();
                          },
                          accent: widget.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Settings picker ────────────────────────────────────────
                _SectionLabel(label: 'App settings', accent: widget.accent),
                const SizedBox(height: 8),
                _CheckGroup(
                  children: [
                    _SimpleCheckRow(
                      icon: Icons.tune_rounded,
                      label: 'UI preferences',
                      subtitle:
                          'Theme, density, date format, thread display options',
                      checked: _includeSettings,
                      onChanged: (val) {
                        setState(() => _includeSettings = val);
                        _buildQr();
                      },
                      accent: widget.accent,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── QR code ────────────────────────────────────────────────
                Center(
                  child: !_hasAnythingSelected
                      ? _EmptyQrPlaceholder(
                          hasAccounts: accounts.isNotEmpty,
                          accent: widget.accent,
                        )
                      : _QrCodeView(
                          data: _qrData ?? '',
                          secondsLeft: _secondsLeft,
                          totalSeconds: _kExpirySeconds,
                          timerLabel: _timerLabel,
                          accent: widget.accent,
                          onRefresh: () {
                            // Freshen the settings snapshot on manual refresh.
                            _settingsSnapshot = context.tidingsSettings
                                .transferableSettingsMap();
                            _buildQr();
                          },
                        ),
                ),

                const SizedBox(height: 16),

                // ── Footer note ────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: ColorTokens.textSecondary(context, 0.45),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'QR codes expire after 5 minutes. Passwords are included in plain text — keep the code private.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context, 0.45),
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ── Bordered group container ───────────────────────────────────────────────────

class _CheckGroup extends StatelessWidget {
  const _CheckGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorTokens.border(context, 0.1)),
      ),
      child: Column(children: children),
    );
  }
}

// ── Account checkbox row ───────────────────────────────────────────────────────

class _AccountCheckRow extends StatelessWidget {
  const _AccountCheckRow({
    required this.account,
    required this.checked,
    required this.onChanged,
    required this.accent,
  });

  final EmailAccount account;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isGmail = account.providerType == EmailProviderType.gmail;

    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isGmail
                    ? const Color(0xFF4285F4).withValues(alpha: 0.12)
                    : ColorTokens.cardFill(context, 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                isGmail ? Icons.mail_rounded : Icons.dns_rounded,
                size: 14,
                color: isGmail
                    ? const Color(0xFF4285F4)
                    : ColorTokens.textSecondary(context, 0.7),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (isGmail)
                    Text(
                      'Email only — OAuth not transferable',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context, 0.5),
                            fontSize: 11,
                          ),
                    )
                  else
                    Text(
                      account.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context),
                          ),
                    ),
                ],
              ),
            ),
            Checkbox(
              value: checked,
              onChanged: (val) => onChanged(val ?? false),
              activeColor: accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Simple (non-account) checkbox row ─────────────────────────────────────────

class _SimpleCheckRow extends StatelessWidget {
  const _SimpleCheckRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ColorTokens.cardFill(context, 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                size: 15,
                color: ColorTokens.textSecondary(context, 0.7),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColorTokens.textSecondary(context, 0.55),
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: checked,
              onChanged: (val) => onChanged(val ?? false),
              activeColor: accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ── QR code widget with countdown ─────────────────────────────────────────────

class _QrCodeView extends StatelessWidget {
  const _QrCodeView({
    required this.data,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.timerLabel,
    required this.accent,
    required this.onRefresh,
  });

  final String data;
  final int secondsLeft;
  final int totalSeconds;
  final String timerLabel;
  final Color accent;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 1.0;
    final isExpiringSoon = secondsLeft < 60;

    final timerColor = isExpiringSoon
        ? Colors.orangeAccent
        : ColorTokens.textSecondary(context, 0.6);

    return Column(
      children: [
        // QR with white background padding (always light so scanners work).
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: data.isEmpty
              ? const SizedBox(width: 220, height: 220)
              : QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
        ),

        const SizedBox(height: 14),

        // Progress bar.
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: ColorTokens.border(context, 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                isExpiringSoon ? Colors.orangeAccent : accent,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Timer row.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: timerColor),
            const SizedBox(width: 4),
            Text(
              'Expires in $timerLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: timerColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Empty state placeholder ────────────────────────────────────────────────────

class _EmptyQrPlaceholder extends StatelessWidget {
  const _EmptyQrPlaceholder({
    required this.hasAccounts,
    required this.accent,
  });

  final bool hasAccounts;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      height: 252,
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 48,
              color: ColorTokens.textSecondary(context, 0.25),
            ),
            const SizedBox(height: 10),
            Text(
              hasAccounts
                  ? 'Select at least one item\nto generate a QR code.'
                  : 'Nothing selected to transfer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context, 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
