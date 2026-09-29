import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hero Banner inviting users to scan documents with a scan button and phone mockup graphic.
class HeroScanBanner extends StatelessWidget {
  const HeroScanBanner({
    super.key,
    required this.onScanNow,
  });

  final VoidCallback onScanNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEBF5FE),
            Color(0xFFF1F6FE),
            Color(0xFFF8FAFD),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDBEAFE).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Column: Text & CTA Button
          Expanded(
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan Documents\nin Seconds',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Turn your paper documents, receipts, invoices and more into high-quality PDFs.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                // Scan Now CTA Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onScanNow,
                    borderRadius: BorderRadius.circular(24),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Scan Now',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right Graphic: Smartphone Scanner Mockup with Document
          Expanded(
            flex: 8,
            child: SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Coffee cup decoration top right
                  Positioned(
                    top: -6,
                    right: -4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B2F2F),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Background paper sheet tilted left
                  Positioned(
                    left: 2,
                    top: 10,
                    child: Transform.rotate(
                      angle: -math.pi / 22,
                      child: Container(
                        width: 95,
                        height: 130,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INVOICE',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildDocLine(width: 50),
                            const SizedBox(height: 3),
                            _buildDocLine(width: 65),
                            const SizedBox(height: 3),
                            _buildDocLine(width: 40),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Smartphone with Camera Viewfinder
                  Positioned(
                    right: 4,
                    bottom: 0,
                    child: Container(
                      width: 98,
                      height: 154,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF1E293B),
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(2, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: const Color(0xFF1E293B),
                          child: Column(
                            children: [
                              // Top speaker notch
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 22,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              // Viewfinder screen
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Simulated document being scanned
                                      Center(
                                        child: Container(
                                          width: 68,
                                          height: 88,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'INVOICE',
                                                style: TextStyle(
                                                  fontSize: 6,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              _buildDocLine(width: 44),
                                              const SizedBox(height: 3),
                                              _buildDocLine(width: 52),
                                              const SizedBox(height: 3),
                                              _buildDocLine(width: 36),
                                              const SizedBox(height: 4),
                                              _buildDocLine(width: 48),
                                              const SizedBox(height: 3),
                                              _buildDocLine(width: 40),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Blue crop/detection corners
                                      const Positioned.fill(
                                        child: Padding(
                                          padding: EdgeInsets.all(4),
                                          child: _ViewfinderCorners(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Camera Controls Bar (Gallery, Shutter, Flash)
                              Container(
                                height: 26,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(
                                      Icons.image_outlined,
                                      size: 10,
                                      color: Colors.white70,
                                    ),
                                    // Shutter button
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      size: 10,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  static Widget _buildDocLine({required double width}) {
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Custom painter for the 4 blue viewfinder corners on the phone camera preview.
class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornersPainter(),
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 8.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
