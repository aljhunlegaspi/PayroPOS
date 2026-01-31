import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/product_provider.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final bool returnResult;

  const BarcodeScannerScreen({super.key, this.returnResult = true});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final code = barcode.rawValue;

    if (code == null || code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Check if product exists
    final existingProduct = await ref.read(productProvider.notifier).findByBarcode(code);

    if (!mounted) return;

    if (widget.returnResult) {
      // Return the barcode to the previous screen
      context.pop(code);
    } else {
      // Show product info or navigate to add product
      if (existingProduct != null) {
        _showProductFoundDialog(existingProduct, code);
      } else {
        _showProductNotFoundDialog(code);
      }
    }

    setState(() => _isProcessing = false);
  }

  void _showProductFoundDialog(Product product, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Price: ₱${product.price.toStringAsFixed(2)}'),
            Text('Stock: ${product.getTotalStock()}'),
            if (product.barcode != null) Text('Barcode: ${product.barcode}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _lastScannedCode = null);
            },
            child: const Text('Scan Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
              context.push('/products/edit/${product.id}');
            },
            child: const Text('View Product'),
          ),
        ],
      ),
    );
  }

  void _showProductNotFoundDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text('No product found with barcode:\n$code\n\nWould you like to add it?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _lastScannedCode = null);
            },
            child: const Text('Scan Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
              context.push('/products/add', extra: code);
            },
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  void _toggleTorch() {
    _controller?.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  void _switchCamera() {
    _controller?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Scan Overlay
          _buildScanOverlay(),

          // Bottom Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isProcessing)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Text(
                      'Point camera at barcode or QR code',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  // Manual Input Button
                  OutlinedButton.icon(
                    onPressed: () => _showManualInputDialog(),
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    label: const Text('Enter Manually', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final left = (constraints.maxWidth - scanAreaSize) / 2;
        final top = (constraints.maxHeight - scanAreaSize) / 2 - 50;

        return Stack(
          children: [
            // Darkened areas
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Corner decorations
            Positioned(
              left: left,
              top: top,
              child: _buildCorner(true, true),
            ),
            Positioned(
              right: left,
              top: top,
              child: _buildCorner(false, true),
            ),
            Positioned(
              left: left,
              bottom: constraints.maxHeight - top - scanAreaSize,
              child: _buildCorner(true, false),
            ),
            Positioned(
              right: left,
              bottom: constraints.maxHeight - top - scanAreaSize,
              child: _buildCorner(false, false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(bool isLeft, bool isTop) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _CornerPainter(
          isLeft: isLeft,
          isTop: isTop,
          color: AppColors.primary,
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter barcode or SKU',
            prefixIcon: Icon(Icons.qr_code),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              if (widget.returnResult) {
                context.pop(value);
              } else {
                _onBarcodeDetected(BarcodeCapture(
                  barcodes: [Barcode(rawValue: value)],
                ));
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context);
                if (widget.returnResult) {
                  context.pop(value);
                } else {
                  _lastScannedCode = value;
                  _onBarcodeDetected(BarcodeCapture(
                    barcodes: [Barcode(rawValue: value)],
                  ));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  final Color color;

  _CornerPainter({
    required this.isLeft,
    required this.isTop,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isLeft && isTop) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (!isLeft && isTop) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (isLeft && !isTop) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
