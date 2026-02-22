import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../state/app_state.dart';
import '../state/qr_transfer.dart';
import '../state/tidings_settings.dart';
import '../theme/color_tokens.dart';
import '../theme/glass.dart';
import 'onboarding_screen.dart';

/// Full-screen QR scanner that imports account settings from a desktop QR code.
///
/// Navigates back (or pops) once accounts are successfully imported, or
/// when the user taps the close button.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.appState,
    required this.accent,
  });

  final AppState appState;
  final Color accent;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  String? _errorMessage;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Barcode handling ───────────────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    await _controller.stop();

    final payloads = _decodePayloads(raw);

    if (payloads == null) {
      setState(() {
        _processing = false;
        _errorMessage = 'QR code is invalid or has expired. '
            'Generate a new one on your desktop and try again.';
      });
      await _controller.start();
      return;
    }

    // Import each account.
    final errors = <String>[];
    for (final payload in payloads) {
      final error = await _importPayload(payload);
      if (error != null) errors.add(error);
    }

    if (!mounted) return;

    if (errors.isNotEmpty) {
      setState(() {
        _processing = false;
        _errorMessage = errors.join('\n');
      });
      await _controller.start();
      return;
    }

    // All good — pop back to onboarding / wherever we came from.
    if (mounted) Navigator.of(context).pop();
  }

  /// Decodes a raw QR string into one or more payloads.
  /// Returns null if invalid/expired.
  List<QrTransferPayload>? _decodePayloads(String raw) {
    // Multi-payload format: "multi:[<encoded1>,<encoded2>,...]"
    if (raw.startsWith('multi:[') && raw.endsWith(']')) {
      final inner = raw.substring('multi:['.length, raw.length - 1);
      final parts = inner.split(',');
      final results = <QrTransferPayload>[];
      for (final part in parts) {
        final p = QrTransferPayload.decode(part.trim());
        if (p == null) return null; // any expired payload fails the whole scan
        results.add(p);
      }
      return results.isEmpty ? null : results;
    }

    // Single payload.
    final p = QrTransferPayload.decode(raw);
    return p == null ? null : [p];
  }

  /// Imports a single decoded payload.  Returns an error string on failure.
  Future<String?> _importPayload(QrTransferPayload payload) async {
    if (payload is ImapQrPayload) {
      final config = payload.toImapConfig();
      final error = await widget.appState.addImapAccount(
        displayName: payload.displayName,
        email: payload.email,
        config: config,
      );
      return error;
    } else if (payload is GmailQrPayload) {
      // Gmail: pre-fill the email then let the user complete OAuth.
      if (!mounted) return null;
      await connectGmail(context, widget.appState, widget.accent);
      return null;
    } else if (payload is SettingsQrPayload) {
      if (!mounted) return null;
      context.tidingsSettings.applyFromQr(payload.settings);
      return null;
    }
    return 'Unsupported account type.';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera view ────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Overlay ────────────────────────────────────────────────────
          _ScannerOverlay(accent: widget.accent),

          // ── Top bar ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Close
                  _GlassIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  // Torch
                  _GlassIconButton(
                    icon: _torchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    tooltip: _torchOn ? 'Torch on' : 'Torch off',
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom instructions / status ────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: GlassPanel(
                  borderRadius: BorderRadius.circular(20),
                  variant: GlassVariant.sheet,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: _processing
                      ? _ProcessingIndicator(accent: widget.accent)
                      : _Instructions(errorMessage: _errorMessage),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

/// Semi-transparent overlay with a square cut-out for the scan target.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(accent: accent),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const cutSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40; // shifted slightly above centre
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: cutSize, height: cutSize);

    // Dark overlay.
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      paint,
    );

    // Accent border around cut-out.
    final borderPaint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);

    // Corner accents.
    const cornerLen = 24.0;
    const r = 16.0;
    final cornerPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(rect.left + r, rect.top),
        Offset(rect.left + r + cornerLen, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top + r),
        Offset(rect.left, rect.top + r + cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(rect.right - r - cornerLen, rect.top),
        Offset(rect.right - r, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top + r),
        Offset(rect.right, rect.top + r + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(rect.left + r, rect.bottom),
        Offset(rect.left + r + cornerLen, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom - r - cornerLen),
        Offset(rect.left, rect.bottom - r), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(rect.right - r - cornerLen, rect.bottom),
        Offset(rect.right - r, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom - r - cornerLen),
        Offset(rect.right, rect.bottom - r), cornerPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.accent != accent;
}

class _Instructions extends StatelessWidget {
  const _Instructions({this.errorMessage});
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          hasError ? Icons.error_outline_rounded : Icons.qr_code_scanner_rounded,
          size: 20,
          color: hasError
              ? Colors.orangeAccent
              : ColorTokens.textSecondary(context, 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasError ? 'Scan failed' : 'Point at the QR code',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasError ? Colors.orangeAccent : null,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                hasError
                    ? errorMessage!
                    : 'Open Tidings on your desktop → Settings → Accounts → '
                        '"Transfer to mobile", then scan the QR code.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.65),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Importing account…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
