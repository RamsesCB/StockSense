import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isScanning = false;
  String? _userId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userId = prefs.getString('user_id');
      _userName = prefs.getString('user_name');
    });
  }

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
        setState(() => _isScanning = false);

        debugPrint('Barcode found! ${barcode.rawValue}');

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Código Detectado'),
            content: Text(barcode.rawValue!),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isScanning = true);
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

        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            if (!state.isInitialized || !state.isRunning) {
                              return const SizedBox();
                            }

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  color: state.torchState == TorchState.on
                                      ? Colors.amber
                                      : Colors.white,
                                  icon: Icon(
                                    state.torchState == TorchState.on
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                  ),
                                  onPressed: () => _controller.toggleTorch(),
                                ),
                                IconButton(
                                  color: Colors.white,
                                  icon: Icon(
                                    state.cameraDirection == CameraFacing.front
                                        ? Icons.camera_front
                                        : Icons.camera_rear,
                                  ),
                                  onPressed: () => _controller.switchCamera(),
                                ),
                              ],
                            );
                          },
                        ),
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
                    child: (_userId != null && _userName != null)
                        ? QrImageView(
                            data: '$_userName:$_userId',
                            version: QrVersions.auto,
                            size: 200.0,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          )
                        : Icon(
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
                  const Text(
                    'Muestra este código para compartir tu inventario',
                  ),
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
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(rect), cutOutPath),
      backgroundPaint,
    );

    final RRect borderRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    // Draw corners optimized
    final Path cornersPath = Path()
      // Top Left
      ..moveTo(borderRect.left, borderRect.top + borderLength)
      ..lineTo(borderRect.left, borderRect.top)
      ..lineTo(borderRect.left + borderLength, borderRect.top)
      // Top Right
      ..moveTo(borderRect.right, borderRect.top + borderLength)
      ..lineTo(borderRect.right, borderRect.top)
      ..lineTo(borderRect.right - borderLength, borderRect.top)
      // Bottom Left
      ..moveTo(borderRect.left, borderRect.bottom - borderLength)
      ..lineTo(borderRect.left, borderRect.bottom)
      ..lineTo(borderRect.left + borderLength, borderRect.bottom)
      // Bottom Right
      ..moveTo(borderRect.right, borderRect.bottom - borderLength)
      ..lineTo(borderRect.right, borderRect.bottom)
      ..lineTo(borderRect.right - borderLength, borderRect.bottom);

    canvas.drawPath(cornersPath, borderPaint);
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
