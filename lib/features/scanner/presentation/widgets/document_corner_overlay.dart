import 'package:flutter/material.dart';
import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Overlay widget that paints the detected document quadrilateral, corner markers, and state colors.
class DocumentCornerOverlay extends StatelessWidget {
  const DocumentCornerOverlay({
    super.key,
    required this.corners,
    this.detectionState = DetectionState.detected,
  });

  final DocumentCornerPoints corners;
  final DetectionState detectionState;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DocumentQuadPainter(
          corners: corners,
          detectionState: detectionState,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DocumentQuadPainter extends CustomPainter {
  const _DocumentQuadPainter({
    required this.corners,
    required this.detectionState,
  });

  final DocumentCornerPoints corners;
  final DetectionState detectionState;

  Color get _themeColor {
    switch (detectionState) {
      case DetectionState.ready:
        return AppColors.success;
      case DetectionState.holdSteady:
        return AppColors.primaryLight;
      case DetectionState.detected:
        return AppColors.primary;
      case DetectionState.moveCloser:
      case DetectionState.moveFarther:
        return AppColors.warning;
      case DetectionState.searching:
        return Colors.white54;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pTL = Offset(
      corners.topLeftX * size.width,
      corners.topLeftY * size.height,
    );
    final pTR = Offset(
      corners.topRightX * size.width,
      corners.topRightY * size.height,
    );
    final pBR = Offset(
      corners.bottomRightX * size.width,
      corners.bottomRightY * size.height,
    );
    final pBL = Offset(
      corners.bottomLeftX * size.width,
      corners.bottomLeftY * size.height,
    );

    final color = _themeColor;

    // 1. Draw translucent highlight fill over detected document
    final quadPath = Path()
      ..moveTo(pTL.dx, pTL.dy)
      ..lineTo(pTR.dx, pTR.dy)
      ..lineTo(pBR.dx, pBR.dy)
      ..lineTo(pBL.dx, pBL.dy)
      ..close();

    final fillPaint = Paint()
      ..color = color.withValues(
        alpha: detectionState == DetectionState.ready ? 0.22 : 0.12,
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(quadPath, fillPaint);

    // 2. Draw border lines
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = detectionState == DetectionState.ready ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(quadPath, linePaint);

    // 3. Draw corner target reticles
    final reticlePaint = Paint()
      ..color = detectionState == DetectionState.ready ? Colors.white : color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLength = 22.0;

    void drawCorner(Offset point, Offset dir1, Offset dir2) {
      canvas.drawLine(point, point + dir1 * cornerLength, reticlePaint);
      canvas.drawLine(point, point + dir2 * cornerLength, reticlePaint);
    }

    drawCorner(pTL, const Offset(1, 0), const Offset(0, 1));
    drawCorner(pTR, const Offset(-1, 0), const Offset(0, 1));
    drawCorner(pBR, const Offset(-1, 0), const Offset(0, -1));
    drawCorner(pBL, const Offset(1, 0), const Offset(0, -1));

    // 4. Draw corner dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pTL, 4, dotPaint);
    canvas.drawCircle(pTR, 4, dotPaint);
    canvas.drawCircle(pBR, 4, dotPaint);
    canvas.drawCircle(pBL, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DocumentQuadPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.detectionState != detectionState;
  }
}
