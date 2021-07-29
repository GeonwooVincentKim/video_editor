import 'package:flutter/material.dart';
import 'package:video_editor/domain/entities/cover_style.dart';

class CoverSliderPainter extends CustomPainter {
  CoverSliderPainter(this.rect, this.position, {this.style});

  final Rect rect;
  final double position;
  final CoverSliderStyle? style;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = style!.background;
    final position = Paint()
      ..color = style!.lineColor
      ..strokeWidth = style!.lineWidth
      ..style = PaintingStyle.stroke;

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

  @override
  bool shouldRepaint(CoverSliderPainter oldDelegate) => true;

  @override
  bool shouldRebuildSemantics(CoverSliderPainter oldDelegate) => false;
}
