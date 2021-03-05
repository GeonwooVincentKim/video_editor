import 'package:flutter/material.dart';
import 'package:video_editor/utils/styles.dart';

class CoverSliderPainter extends CustomPainter {
  CoverSliderPainter(this.rect, this.position, {this.style, this.cropHeight});

  final Rect rect;
  final double position;
  final CoverSliderStyle style;
  final double cropHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = style.background;
    final position = Paint()
      ..color = style.lineColor
      ..strokeWidth = style.lineWidth
      ..style = PaintingStyle.stroke;

    // Hide crop painted area from slider
    if (cropHeight != null) {
      // BACKGROUND LEFT
      canvas.drawRect(
          Rect.fromLTWH(
              0, (size.height - cropHeight) / 2, rect.left, cropHeight),
          background);

      // BACKGROUND RIGHT
      canvas.drawRect(
          Rect.fromLTWH(rect.right, (size.height - cropHeight) / 2, size.width,
              cropHeight),
          background);

      // POSITION RECT
      canvas.drawRect(
        Rect.fromCenter(
            center: rect.center,
            width: rect.width - position.strokeWidth,
            height: cropHeight - position.strokeWidth),
        position,
      );
    } else {
      // BACKGROUND LEFT
      canvas.drawRect(
        Rect.fromPoints(
          Offset.zero,
          rect.bottomLeft,
        ),
        background,
      );

      // BACKGROUND RIGHT
      canvas.drawRect(
        Rect.fromPoints(
          rect.topRight,
          Offset(size.width, size.height),
        ),
        background,
      );

      // RECT
      canvas.drawRect(
        Rect.fromPoints(
          Offset(rect.left + position.strokeWidth / 2,
              rect.bottom - position.strokeWidth / 2),
          Offset(rect.right - position.strokeWidth / 2,
              rect.top + position.strokeWidth / 2),
        ),
        position,
      );
    }
  }

  @override
  bool shouldRepaint(CoverSliderPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(CoverSliderPainter oldDelegate) => false;
}
