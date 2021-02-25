import 'package:flutter/material.dart';
import 'package:video_editor/utils/styles.dart';

class CoverSliderPainter extends CustomPainter {
  CoverSliderPainter(this.rect, this.position, {this.style});

  final Rect rect;
  final double position;
  final TrimSliderStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = style.lineWidth;
    final Paint linePaint = Paint()..color = Colors.white;
    final Paint background = Paint()..color = Colors.white.withOpacity(0.6);

    //BACKGROUND LEFT
    canvas.drawRect(
      Rect.fromPoints(
        Offset.zero,
        rect.bottomLeft,
      ),
      background,
    );

    //BACKGROUND RIGHT
    canvas.drawRect(
      Rect.fromPoints(
        rect.topRight,
        Offset(size.width, size.height),
      ),
      background,
    );

    //TOP RECT
    canvas.drawRect(
      Rect.fromPoints(
        rect.topLeft,
        rect.topRight + Offset(0.0, width),
      ),
      linePaint,
    );

    //RIGHT RECT
    canvas.drawRect(
      Rect.fromPoints(
        rect.topRight - Offset(width, -width),
        rect.bottomRight,
      ),
      linePaint,
    );

    //BOTTOM RECT
    canvas.drawRect(
      Rect.fromPoints(
        rect.bottomRight - Offset(width, width),
        rect.bottomLeft,
      ),
      linePaint,
    );

    //LEFT RECT
    canvas.drawRect(
      Rect.fromPoints(
        rect.bottomLeft - Offset(-width, width),
        rect.topLeft,
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(CoverSliderPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(CoverSliderPainter oldDelegate) => false;
}
