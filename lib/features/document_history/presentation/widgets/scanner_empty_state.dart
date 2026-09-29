import 'package:flutter/material.dart';

/// Clean stylized empty state widget matching AnuScan screenshot:
/// Viewfinder document graphic with sparkle stars +
/// "No Documents Yet"
/// "Scan your first document or import from gallery to get started."
class ScannerEmptyState extends StatelessWidget {
  const ScannerEmptyState({
    super.key,
    this.onScanPressed,
    this.onGalleryPressed,
  });

  final VoidCallback? onScanPressed;
  final VoidCallback? onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration Stack
          SizedBox(
            width: 170,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft shadow oval platform at the base
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 130,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2EAFD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Tilted light-blue document background sheet
                Positioned(
                  top: 14,
                  child: Transform.rotate(
                    angle: -0.10,
                    child: Container(
                      width: 90,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF3FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Main white document card with scanner corners
                Positioned(
                  top: 10,
                  child: Container(
                    width: 86,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Blue Corner Brackets
                        const Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: _EmptyStateCorners(),
                          ),
                        ),

                        // Document symbol with horizontal lines
                        Container(
                          width: 32,
                          height: 38,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sparkle Stars
                // Top-right star
                const Positioned(
                  top: 6,
                  right: 22,
                  child: _SparkleStar(size: 16, color: Color(0xFF93C5FD)),
                ),
                // Mid-right star
                const Positioned(
                  top: 48,
                  right: 14,
                  child: _SparkleStar(size: 12, color: Color(0xFFBFDBFE)),
                ),
                // Mid-left star
                const Positioned(
                  top: 52,
                  left: 18,
                  child: _SparkleStar(size: 14, color: Color(0xFF93C5FD)),
                ),
                // Lower-left star
                const Positioned(
                  bottom: 30,
                  left: 28,
                  child: _SparkleStar(size: 9, color: Color(0xFFBFDBFE)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'No Documents Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          const Text(
            'Scan your first document or import from gallery\nto get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-point sparkle star drawn with custom painter.
class _SparkleStar extends StatelessWidget {
  const _SparkleStar({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(color),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final halfW = size.width / 2;
    final halfH = size.height / 2;

    path.moveTo(halfW, 0);
    path.quadraticBezierTo(halfW, halfH, size.width, halfH);
    path.quadraticBezierTo(halfW, halfH, halfW, size.height);
    path.quadraticBezierTo(halfW, halfH, 0, halfH);
    path.quadraticBezierTo(halfW, halfH, halfW, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyStateCorners extends StatelessWidget {
  const _EmptyStateCorners();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornersBoxPainter(),
    );
  }
}

class _CornersBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 9.0;

    // Top Left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);

    // Top Right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - len, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, len),
      paint,
    );

    // Bottom Left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - len),
      paint,
    );

    // Bottom Right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
