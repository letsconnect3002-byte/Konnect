import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CropImagePage extends StatefulWidget {
  final Uint8List imageBytes;

  const CropImagePage({super.key, required this.imageBytes});

  @override
  State<CropImagePage> createState() => _CropImagePageState();
}

class _CropImagePageState extends State<CropImagePage> {
  static const double viewportSize = 300.0;

  bool _isDecoding = true;
  bool _isCropping = false;
  img.Image? _decodedImage;
  late TransformationController _transformationController;

  double childWidth = 300.0;
  double childHeight = 300.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _decodeImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    try {
      final image = img.decodeImage(widget.imageBytes);
      if (image == null) {
        throw Exception("Failed to decode image");
      }

      final double aspect = image.width / image.height;
      if (image.width >= image.height) {
        childHeight = viewportSize;
        childWidth = viewportSize * aspect;
      } else {
        childWidth = viewportSize;
        childHeight = viewportSize / aspect;
      }

      double initialTx = 0.0;
      double initialTy = 0.0;

      if (childWidth > viewportSize) {
        initialTx = -(childWidth - viewportSize) / 2;
      }
      if (childHeight > viewportSize) {
        initialTy = -(childHeight - viewportSize) / 2;
      }

      _transformationController.value =
          Matrix4.translationValues(initialTx, initialTy, 0.0);

      if (mounted) {
        setState(() {
          _decodedImage = image;
          _isDecoding = false;
        });
      }
    } catch (e) {
      debugPrint("Error decoding image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading image: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cropAndFinish() async {
    if (_decodedImage == null || _isCropping) return;

    setState(() {
      _isCropping = true;
    });

    // Run cropping in a slight delay to allow loading spinner to render
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final matrix = _transformationController.value;
      final double scale = matrix.row0.x; // Scale factor
      final double tx = matrix.row0.w; // Translation X
      final double ty = matrix.row1.w; // Translation Y

      // Calculate translation relative to scale
      final double childX = -tx / scale;
      final double childY = -ty / scale;
      final double childW = viewportSize / scale;
      final double childH = viewportSize / scale;

      // Scale factors to map child coordinates to original image pixels
      final double scaleX = _decodedImage!.width / childWidth;
      final double scaleY = _decodedImage!.height / childHeight;

      int cropX = (childX * scaleX).round();
      int cropY = (childY * scaleY).round();
      int cropW = (childW * scaleX).round();
      int cropH = (childH * scaleY).round();

      // Clamp coordinates to remain strictly within original boundaries
      cropX = cropX.clamp(0, _decodedImage!.width - 1);
      cropY = cropY.clamp(0, _decodedImage!.height - 1);
      cropW = cropW.clamp(1, _decodedImage!.width - cropX);
      cropH = cropH.clamp(1, _decodedImage!.height - cropY);

      final cropped = img.copyCrop(
        _decodedImage!,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final croppedBytes =
          Uint8List.fromList(img.encodeJpg(cropped, quality: 90));

      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      debugPrint("Error cropping image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cropping failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isCropping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0F),
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Crop Profile Photo",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (_isDecoding)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            )
          else ...[
            // Image viewport area
            Center(
              child: Container(
                width: viewportSize,
                height: viewportSize,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  boundaryMargin: EdgeInsets.zero,
                  child: Image.memory(
                    widget.imageBytes,
                    width: childWidth,
                    height: childHeight,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),

            // Semi-transparent overlay with circle crop viewport cutout
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CropOverlayPainter(viewportSize: viewportSize),
                ),
              ),
            ),

            // Bottom action buttons
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Pinch to zoom and drag to adjust",
                    style: TextStyle(
                      color: Color(0xFF8B8C9E),
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF26273C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _cropAndFinish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "Crop & Apply",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_isCropping)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Cropping image...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
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
}

class CropOverlayPainter extends CustomPainter {
  final double viewportSize;

  CropOverlayPainter({required this.viewportSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height / 2);
    final radius = viewportSize / 2;
    final innerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00F2FE), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
