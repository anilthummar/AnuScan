import 'package:flutter/material.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scanned_page.dart';
import '../widgets/perspective_crop_widget.dart';

/// Screen allowing the user to adjust the 4 corner points of a document page.
class PerspectiveCropScreen extends StatefulWidget {
  const PerspectiveCropScreen({super.key, required this.page});

  final ScanPage page;

  @override
  State<PerspectiveCropScreen> createState() => _PerspectiveCropScreenState();
}

class _PerspectiveCropScreenState extends State<PerspectiveCropScreen> {
  CropCorners? _currentCorners;

  @override
  void initState() {
    super.initState();
    _currentCorners = widget.page.corners ?? CropCorners.fullBounds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Crop & Perspective',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Crop',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _currentCorners = CropCorners.fullBounds();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Informative guide
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white10,
              child: const Row(
                children: [
                  Icon(
                    Icons.crop_free,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drag corners to align with the document boundaries',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Interactive 4-corner canvas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: PerspectiveCropWidget(
                  imagePath: widget.page.originalImagePath,
                  imageWidth: widget.page.width,
                  imageHeight: widget.page.height,
                  initialCorners: _currentCorners,
                  onCornersChanged: (corners) {
                    _currentCorners = corners;
                  },
                ),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                      ),
                      onPressed: () {
                        Navigator.pop(context, _currentCorners);
                      },
                      child: const Text('Apply Crop'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
