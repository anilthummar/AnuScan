import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Interactive quadrilateral 4-point corner adjustment widget.
class PerspectiveCropWidget extends StatefulWidget {
  const PerspectiveCropWidget({
    super.key,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    this.initialCorners,
    required this.onCornersChanged,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final CropCorners? initialCorners;
  final ValueChanged<CropCorners> onCornersChanged;

  @override
  State<PerspectiveCropWidget> createState() => _PerspectiveCropWidgetState();
}

class _PerspectiveCropWidgetState extends State<PerspectiveCropWidget> {
  late Offset _tl;
  late Offset _tr;
  late Offset _bl;
  late Offset _br;

  late int _resolvedWidth;
  late int _resolvedHeight;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _resolvedWidth = widget.imageWidth;
    _resolvedHeight = widget.imageHeight;
    _initCorners();

    if (_resolvedWidth <= 0 || _resolvedHeight <= 0) {
      _resolveImageDimensions();
    }
  }

  void _resolveImageDimensions() {
    final image = FileImage(File(widget.imagePath));
    _imageStream = image.resolve(ImageConfiguration.empty);
    _imageStreamListener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _resolvedWidth = info.image.width;
          _resolvedHeight = info.image.height;
        });
      }
      if (_imageStream != null && _imageStreamListener != null) {
        _imageStream!.removeListener(_imageStreamListener!);
        _imageStream = null;
        _imageStreamListener = null;
      }
    });
    _imageStream!.addListener(_imageStreamListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
      _imageStream = null;
      _imageStreamListener = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PerspectiveCropWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCorners != oldWidget.initialCorners &&
        widget.initialCorners != null) {
      setState(() {
        _initCorners();
      });
    }
  }

  void _initCorners() {
    final c = widget.initialCorners ?? CropCorners.fullBounds();
    _tl = Offset(c.topLeftX, c.topLeftY);
    _tr = Offset(c.topRightX, c.topRightY);
    _bl = Offset(c.bottomLeftX, c.bottomLeftY);
    _br = Offset(c.bottomRightX, c.bottomRightY);
  }

  void _notifyChange() {
    widget.onCornersChanged(
      CropCorners(
        topLeftX: _tl.dx,
        topLeftY: _tl.dy,
        topRightX: _tr.dx,
        topRightY: _tr.dy,
        bottomLeftX: _bl.dx,
        bottomLeftY: _bl.dy,
        bottomRightX: _br.dx,
        bottomRightY: _br.dy,
      ),
    );
  }

  void resetToFullBounds() {
    setState(() {
      _tl = const Offset(0.0, 0.0);
      _tr = const Offset(1.0, 0.0);
      _bl = const Offset(0.0, 1.0);
      _br = const Offset(1.0, 1.0);
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imgW = _resolvedWidth > 0 ? _resolvedWidth.toDouble() : 1.0;
        final imgH = _resolvedHeight > 0 ? _resolvedHeight.toDouble() : 1.0;
        final imageAspect = imgW / imgH;

        double renderW;
        double renderH;

        if (constraints.maxWidth / constraints.maxHeight > imageAspect) {
          renderH = constraints.maxHeight;
          renderW = renderH * imageAspect;
        } else {
          renderW = constraints.maxWidth;
          renderH = renderW / imageAspect;
        }

        return Center(
          child: SizedBox(
            width: renderW,
            height: renderH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Underlying source image
                Positioned.fill(
                  child: Image.file(File(widget.imagePath), fit: BoxFit.fill),
                ),

                // Quadrilateral polygon overlay & boundary lines
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PerspectiveOverlayPainter(
                      tl: _tl,
                      tr: _tr,
                      bl: _bl,
                      br: _br,
                    ),
                  ),
                ),

                // 4 Interactive Corner Drag Handles
                _buildHandle(
                  position: _tl,
                  renderWidth: renderW,
                  renderHeight: renderH,
                  onDrag: (newOffset) {
                    setState(() {
                      _tl = Offset(
                        newOffset.dx.clamp(0.0, _tr.dx - 0.05),
                        newOffset.dy.clamp(0.0, _bl.dy - 0.05),
                      );
                    });
                    _notifyChange();
                  },
                ),
                _buildHandle(
                  position: _tr,
                  renderWidth: renderW,
                  renderHeight: renderH,
                  onDrag: (newOffset) {
                    setState(() {
                      _tr = Offset(
                        newOffset.dx.clamp(_tl.dx + 0.05, 1.0),
                        newOffset.dy.clamp(0.0, _br.dy - 0.05),
                      );
                    });
                    _notifyChange();
                  },
                ),
                _buildHandle(
                  position: _bl,
                  renderWidth: renderW,
                  renderHeight: renderH,
                  onDrag: (newOffset) {
                    setState(() {
                      _bl = Offset(
                        newOffset.dx.clamp(0.0, _br.dx - 0.05),
                        newOffset.dy.clamp(_tl.dy + 0.05, 1.0),
                      );
                    });
                    _notifyChange();
                  },
                ),
                _buildHandle(
                  position: _br,
                  renderWidth: renderW,
                  renderHeight: renderH,
                  onDrag: (newOffset) {
                    setState(() {
                      _br = Offset(
                        newOffset.dx.clamp(_bl.dx + 0.05, 1.0),
                        newOffset.dy.clamp(_tr.dy + 0.05, 1.0),
                      );
                    });
                    _notifyChange();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle({
    required Offset position,
    required double renderWidth,
    required double renderHeight,
    required ValueChanged<Offset> onDrag,
  }) {
    const handleSize = 44.0;
    final px = position.dx * renderWidth;
    final py = position.dy * renderHeight;

    return Positioned(
      left: px - (handleSize / 2),
      top: py - (handleSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final newDx = (px + details.delta.dx) / renderWidth;
          final newDy = (py + details.delta.dy) / renderHeight;
          onDrag(Offset(newDx, newDy));
        },
        child: Container(
          width: handleSize,
          height: handleSize,
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.cropHandle,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerspectiveOverlayPainter extends CustomPainter {
  const _PerspectiveOverlayPainter({
    required this.tl,
    required this.tr,
    required this.bl,
    required this.br,
  });

  final Offset tl;
  final Offset tr;
  final Offset bl;
  final Offset br;

  @override
  void paint(Canvas canvas, Size size) {
    final pTl = Offset(tl.dx * size.width, tl.dy * size.height);
    final pTr = Offset(tr.dx * size.width, tr.dy * size.height);
    final pBl = Offset(bl.dx * size.width, bl.dy * size.height);
    final pBr = Offset(br.dx * size.width, br.dy * size.height);

    // Dark dimmed background outside polygon
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final polyPath = Path()
      ..moveTo(pTl.dx, pTl.dy)
      ..lineTo(pTr.dx, pTr.dy)
      ..lineTo(pBr.dx, pBr.dy)
      ..lineTo(pBl.dx, pBl.dy)
      ..close();

    final maskPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      polyPath,
    );

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawPath(maskPath, dimPaint);

    // Quad border lines
    final linePaint = Paint()
      ..color = AppColors.cropLine
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(polyPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PerspectiveOverlayPainter oldDelegate) {
    return oldDelegate.tl != tl ||
        oldDelegate.tr != tr ||
        oldDelegate.bl != bl ||
        oldDelegate.br != br;
  }
}
