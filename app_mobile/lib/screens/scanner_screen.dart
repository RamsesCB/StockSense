import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // MobileScannerController to control camera (torch, switch camera)
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isScanning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isScanning = false); // Stop scanning to show result

        debugPrint('Barcode found! ${barcode.rawValue}');

        if (!mounted) return;

        // Show dialog with result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Código Detectado'),
            content: Text(barcode.rawValue!),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isScanning = true); // Resume scanning
                },
                child: const Text('OK'),
              ),
            ],
          ),
        ).then((_) {
          if (mounted) {
            setState(() => _isScanning = true);
          }
        });

        break; // Only handle first code
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner QR'),
        actions: [
          // Torch Button
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final color = state.torchState == TorchState.on
                  ? Colors.yellow
                  : Colors.grey;
              final icon = state.torchState == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off;
              return IconButton(
                icon: Icon(icon, color: color),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          // Camera Switch Button
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final icon = state.cameraDirection == CameraFacing.front
                  ? Icons.camera_front
                  : Icons.camera_rear;
              return IconButton(
                icon: Icon(icon),
                onPressed: () => _controller.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: _isScanning
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                ),
                Positioned.fill(
                  child: Container(
                    decoration: ShapeDecoration(
                      shape: QrScannerOverlayShape(
                        borderColor: Theme.of(context).colorScheme.primary,
                        borderRadius: 10,
                        borderLength: 30,
                        borderWidth: 10,
                        cutOutSize: 300,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const Text(
                        'Apunta al código QR del producto',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isScanning = false),
                        icon: const Icon(Icons.close),
                        label: const Text('Cerrar Cámara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      size: 200,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Mi Código QR',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Muestra este código para recibir préstamos'),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isScanning = true),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Escanear QR'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Utility class for the Overlay Shape (copy-paste standard or use a library,
// strictly creating a simple one here conceptually, but for simplicity relying on a simplistic
// Container with border or just the bare scanner if User didn't ask for overlay logic explicitly.
// But MobileScanner typically works best with a visual guide.
// Implementing a custom simplified painter to avoid complex deps if needed,
// BUT mobile_scanner package used to have an overlay.
// Checking recent docs: built-in overlay is gone in v5?
// Let's implement a simple Stack with a hole or just a border.
// Actually, let's keep it simple for now, the OverlayShape is not part of material.
// I'll create a simple specific class for this or simpler UI.

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 10.0,
    this.borderLength = 20.0,
    this.cutOutSize = 250.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  // Custom painter is complex to implement fully inline correctly without errors.
  // I will revert to a standard Container approach for the overlay to ensure it compiles safely.
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutPath = Path()..addRect(cutOutRect);
    // Draw background with hole
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(rect), cutOutPath),
      backgroundPaint,
    );

    // Draw corners
    final RRect borderRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(borderRect.left, borderRect.top + borderLength)
        ..lineTo(borderRect.left, borderRect.top)
        ..lineTo(borderRect.left + borderLength, borderRect.top),
      borderPaint,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(borderRect.right, borderRect.top + borderLength)
        ..lineTo(borderRect.right, borderRect.top)
        ..lineTo(borderRect.right - borderLength, borderRect.top),
      borderPaint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(borderRect.left, borderRect.bottom - borderLength)
        ..lineTo(borderRect.left, borderRect.bottom)
        ..lineTo(borderRect.left + borderLength, borderRect.bottom),
      borderPaint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(borderRect.right, borderRect.bottom - borderLength)
        ..lineTo(borderRect.right, borderRect.bottom)
        ..lineTo(borderRect.right - borderLength, borderRect.bottom),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
