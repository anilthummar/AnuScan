import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/image_processing_service.dart';

void main() {
  group(
    'DocumentCornerPoints Geometry & Validation (Phase 10.6, 10.7, 10.8)',
    () {
      test(
        'standard valid rectangular quad passes isConvex and isValidQuad',
        () {
          const quad = DocumentCornerPoints(
            topLeftX: 0.1,
            topLeftY: 0.1,
            topRightX: 0.9,
            topRightY: 0.1,
            bottomLeftX: 0.1,
            bottomLeftY: 0.9,
            bottomRightX: 0.9,
            bottomRightY: 0.9,
          );

          expect(quad.isConvex, isTrue);
          expect(quad.isValidQuad, isTrue);
          expect(quad.quadArea, closeTo(0.64, 0.001));
          expect(quad.aspectRatio, closeTo(1.0, 0.01));
          expect(quad.centerOffset, closeTo(0.0, 0.01));
        },
      );

      test(
        'bow-tie / self-intersecting quad fails isConvex and isValidQuad',
        () {
          // Crossed top-right and bottom-right points
          const invalidQuad = DocumentCornerPoints(
            topLeftX: 0.1,
            topLeftY: 0.1,
            topRightX: 0.9,
            topRightY: 0.9, // inverted
            bottomLeftX: 0.1,
            bottomLeftY: 0.9,
            bottomRightX: 0.9,
            bottomRightY: 0.1, // inverted
          );

          expect(invalidQuad.isConvex, isFalse);
          expect(invalidQuad.isValidQuad, isFalse);
        },
      );

      test('collinear or degenerate points fail isConvex and isValidQuad', () {
        // All points on same horizontal line
        const degenerateQuad = DocumentCornerPoints(
          topLeftX: 0.1,
          topLeftY: 0.5,
          topRightX: 0.4,
          topRightY: 0.5,
          bottomLeftX: 0.6,
          bottomLeftY: 0.5,
          bottomRightX: 0.9,
          bottomRightY: 0.5,
        );

        expect(degenerateQuad.isConvex, isFalse);
        expect(degenerateQuad.isValidQuad, isFalse);
        expect(degenerateQuad.quadArea, closeTo(0.0, 0.0001));
      });

      test('points out of bounds [0, 1] fail isValidQuad', () {
        const outOfBoundsQuad = DocumentCornerPoints(
          topLeftX: -0.05,
          topLeftY: 0.1,
          topRightX: 0.9,
          topRightY: 0.1,
          bottomLeftX: 0.1,
          bottomLeftY: 1.05,
          bottomRightX: 0.9,
          bottomRightY: 0.9,
        );

        expect(outOfBoundsQuad.isValidQuad, isFalse);
      });

      test('quad with extreme aspect ratio fails isValidQuad', () {
        // 0.02 width vs 0.9 height = ~0.02 aspect ratio (< 0.15 threshold)
        const needleQuad = DocumentCornerPoints(
          topLeftX: 0.49,
          topLeftY: 0.05,
          topRightX: 0.51,
          topRightY: 0.05,
          bottomLeftX: 0.49,
          bottomLeftY: 0.95,
          bottomRightX: 0.51,
          bottomRightY: 0.95,
        );

        expect(needleQuad.isValidQuad, isFalse);
      });

      test(
        'distanceTo correctly computes Euclidean drift between corner sets',
        () {
          const quadA = DocumentCornerPoints(
            topLeftX: 0.2,
            topLeftY: 0.2,
            topRightX: 0.8,
            topRightY: 0.2,
            bottomLeftX: 0.2,
            bottomLeftY: 0.8,
            bottomRightX: 0.8,
            bottomRightY: 0.8,
          );

          const quadB = DocumentCornerPoints(
            topLeftX: 0.21,
            topLeftY: 0.2,
            topRightX: 0.81,
            topRightY: 0.2,
            bottomLeftX: 0.21,
            bottomLeftY: 0.8,
            bottomRightX: 0.81,
            bottomRightY: 0.8,
          );

          final drift = quadA.distanceTo(quadB);
          expect(drift, closeTo(0.01, 0.001));
        },
      );

      test(
        'withSafetyMargin properly expands corners without exceeding boundaries',
        () {
          const quad = DocumentCornerPoints(
            topLeftX: 0.1,
            topLeftY: 0.1,
            topRightX: 0.9,
            topRightY: 0.1,
            bottomLeftX: 0.1,
            bottomLeftY: 0.9,
            bottomRightX: 0.9,
            bottomRightY: 0.9,
          );

          final expanded = quad.withSafetyMargin(0.05);

          expect(expanded.topLeftX, lessThan(0.1));
          expect(expanded.topLeftY, lessThan(0.1));
          expect(expanded.bottomRightX, greaterThan(0.9));
          expect(expanded.bottomRightY, greaterThan(0.9));

          // Must never exceed [0.0, 1.0]
          expect(expanded.topLeftX, greaterThanOrEqualTo(0.0));
          expect(expanded.topLeftY, greaterThanOrEqualTo(0.0));
          expect(expanded.bottomRightX, lessThanOrEqualTo(1.0));
          expect(expanded.bottomRightY, lessThanOrEqualTo(1.0));
        },
      );
    },
  );
}
