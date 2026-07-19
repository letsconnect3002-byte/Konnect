import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:connect/Config/app_theme.dart';

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

  double _containerWidth = 300.0;
  double _containerHeight = 300.0;
  bool _hasInitializedController = false;

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
      // Scale display dimensions to a max base of 800.0 for optimal performance
      final double targetBase = 800.0;
      if (image.width >= image.height) {
        childHeight = targetBase;
        childWidth = targetBase * aspect;
      } else {
        childWidth = targetBase;
        childHeight = targetBase / aspect;
      }

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
          const SnackBar(
            content: Text("Could not load image. Please select another photo."),
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

      final double cutoutLeft = (_containerWidth - viewportSize) / 2;
      final double cutoutTop = (_containerHeight - viewportSize) / 2;

      // Calculate translation relative to scale
      final double childX = (cutoutLeft - tx) / scale;
      final double childY = (cutoutTop - ty) / scale;
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
          const SnackBar(
            content: Text("Failed to crop image. Please try again."),
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
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    final double minScale = _decodedImage != null
        ? max(viewportSize / childWidth, viewportSize / childHeight)
        : 1.0;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
            // Image viewport area filling the screen above the buttons
            Positioned.fill(
              bottom: 180, // Leave space for bottom buttons
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _containerWidth = constraints.maxWidth;
                  _containerHeight = constraints.maxHeight;

                  final double cutoutLeft = (_containerWidth - viewportSize) / 2;
                  final double cutoutTop = (_containerHeight - viewportSize) / 2;

                  if (!_hasInitializedController) {
                    _hasInitializedController = true;
                    final double initialScale = minScale;
                    final double initialTx =
                        (_containerWidth - childWidth * initialScale) / 2;
                    final double initialTy =
                        (_containerHeight - childHeight * initialScale) / 2;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final matrix = Matrix4.identity();
                      matrix.setEntry(0, 0, initialScale);
                      matrix.setEntry(1, 1, initialScale);
                      matrix.setEntry(0, 3, initialTx);
                      matrix.setEntry(1, 3, initialTy);
                      _transformationController.value = matrix;
                    });
                  }

                  return Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      constrained: false,
                      transformationController: _transformationController,
                      minScale: minScale,
                      maxScale: minScale * 8.0, // Allow up to 8x zoom from minScale
                      boundaryMargin: EdgeInsets.symmetric(
                        horizontal: cutoutLeft,
                        vertical: cutoutTop,
                      ),
                      child: Image.memory(
                        widget.imageBytes,
                        width: childWidth,
                        height: childHeight,
                        cacheWidth: childWidth.round(),
                        cacheHeight: childHeight.round(),
                        fit: BoxFit.fill,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Semi-transparent overlay with circle crop viewport cutout centered in same space
            Positioned.fill(
              bottom: 180,
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
